import 'dart:convert';
import 'dart:io';

import 'package:dd/im_local_store.dart';
import 'package:dd/im_location.dart';
import 'package:dd/post_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const metadata = <String, dynamic>{
    'latitude': 31.23,
    'longitude': 121.47,
    'title': '人民广场',
    'address': '上海市黄浦区',
  };

  test('定位权限拒绝时不获取位置，授权后使用实时坐标', () async {
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    var enabled = true;
    var permission = 0;
    var requested = 0;
    var located = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isLocationServiceEnabled':
          return enabled;
        case 'checkPermission':
          return permission;
        case 'requestPermission':
          requested++;
          return permission;
        case 'getCurrentPosition':
          located++;
          return {
            'latitude': 31.23,
            'longitude': 121.47,
            'timestamp': 1000,
            'accuracy': 5.0,
            'altitude': 0.0,
            'heading': 0.0,
            'speed': 0.0,
            'speed_accuracy': 0.0
          };
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await expectLater(
        ImLocation.current(), throwsA(isA<ImLocationException>()));
    expect(requested, 1);
    expect(located, 0);
    permission = 1;
    await expectLater(
        ImLocation.current(), throwsA(isA<ImLocationException>()));
    expect(requested, 1);
    enabled = false;
    await expectLater(
        ImLocation.current(), throwsA(isA<ImLocationException>()));
    enabled = true;
    permission = 2;
    final location = await ImLocation.current();
    expect(location.latitude, 31.23);
    expect(location.longitude, 121.47);
    expect(location.address, '地址暂不可用');
    expect(located, 1);
  });

  test('发送接口保留位置类型与完整坐标地址', () async {
    final service = DDPostService(client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['kind'], 'location');
      expect(body['metadata'], metadata);
      return http.Response(
          jsonEncode({
            'message': {'id': '1', ...body}
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    addTearDown(service.dispose);
    final result = await service.sendImMessage('token', '1',
        text: '人民广场', clientId: 'c1', kind: 'location', metadata: metadata);
    expect(result['metadata'], metadata);
  });

  test('位置校验拒绝损坏数据且正确编码地图地址', () {
    for (final value in [
      null,
      {},
      {'latitude': 91, 'longitude': 0},
      {'latitude': 'NaN', 'longitude': 0}
    ]) {
      expect(ImLocation.fromMetadata(value), isNull);
    }
    final uri = ImLocation.fromMetadata(metadata)!.mapsUrl;
    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters, {'ll': '31.23,121.47', 'q': '人民广场'});
  });

  testWidgets('位置卡片尺寸稳定并通过地图链接打开', (tester) async {
    String? opened;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      opened = (call.arguments as Map)['url'] as String?;
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const MaterialApp(
        home:
            Scaffold(body: Center(child: ImLocationCard(metadata: metadata)))));
    expect(find.text('人民广场'), findsOneWidget);
    expect(find.text('上海市黄浦区'), findsOneWidget);
    expect(tester.getSize(find.byType(ImLocationCard)), const Size(220, 174));
    expect(
        tester.widget<Icon>(find.byIcon(Icons.location_on)).color, Colors.red);
    await tester.tap(find.text('人民广场'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple 地图'));
    await tester.pumpAndSettle();
    expect(Uri.parse(opened!).queryParameters['q'], '人民广场');
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: ImLocationCard(metadata: null)))));
    expect(find.text('位置不可用'), findsOneWidget);
    expect(tester.getSize(find.byType(ImLocationCard)), const Size(220, 174));
    expect(tester.takeException(), isNull);
  });

  group('位置本地存储', () {
    late Directory directory;
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      directory = await Directory.systemTemp.createTemp('im-location-');
      await databaseFactory.setDatabasesPath(directory.path);
    });
    tearDown(() async {
      await ImLocalStore.close();
      await directory.delete(recursive: true);
    });
    Future<void> save() => ImLocalStore.saveMessages(
            accountId: 'a',
            conversationId: '1',
            messages: [
              {
                'id': 'local:c1',
                'clientId': 'c1',
                'kind': 'location',
                'text': '人民广场',
                'metadata': metadata,
                'status': 'pending',
              }
            ]);
    test('关闭重开和待重试队列保留完整 metadata', () async {
      await save();
      await ImLocalStore.close();
      final rows =
          await ImLocalStore.messages(accountId: 'a', conversationId: '1');
      expect(rows.single['metadata'], metadata);
      expect((await ImLocalStore.pendingMessages('a')).single['metadata'],
          metadata);
      await ImLocalStore.saveIncomingMessage(accountId: 'a', message: {
        'id': '2',
        'conversationId': '1',
        'kind': 'location',
        'metadata': metadata,
      });
      expect(
          (await ImLocalStore.messages(accountId: 'a', conversationId: '1'))
              .every((row) => row['metadata'] is Map),
          isTrue);
    });
    test('第九版数据库升级保留历史文本并支持位置', () async {
      await save();
      await ImLocalStore.close();
      final db = await databaseFactory
          .openDatabase('${directory.path}/friend_im.sqlite');
      await db.execute('ALTER TABLE messages DROP COLUMN metadata');
      await db.setVersion(9);
      await db.update('messages', {'kind': 'text', 'text': '历史消息'});
      await db.close();
      final rows =
          await ImLocalStore.messages(accountId: 'a', conversationId: '1');
      expect(rows.single['text'], '历史消息');
      expect(rows.single['metadata'], isNull);
      await save();
      await ImLocalStore.close();
      expect((await ImLocalStore.pendingMessages('a')).single['metadata'],
          metadata);
    });
  });
}
