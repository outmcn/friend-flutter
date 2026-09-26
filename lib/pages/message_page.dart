import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:friend_app/flyer_example/api/api.dart';
import 'package:friend_app/flyer_example/api_get_chat_id.dart';
import 'package:friend_app/flyer_example/api_get_initial_messages.dart';
import 'package:friend_app/flyer_example/basic.dart';
import 'package:friend_app/flyer_example/gemini.dart';
import 'package:friend_app/flyer_example/local.dart';
import 'package:friend_app/flyer_example/pagination_newer.dart';
import 'package:friend_app/flyer_example/pagination_older.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key, required this.token});
  final String token;
  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final _dio = Dio();
  final _chatId = TextEditingController();
  final _localDio = Dio();
  UserID _currentUserId = 'john';
  bool _busy = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
      await initializeDateFormatting();
      await Hive.initFlutter();
      if (await Hive.boxExists('chat')) {
        await Hive.openBox('chat');
      }
    } catch (e) {
      if (mounted) _message('Flyer 初始化失败：$e');
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _chatId.dispose();
    _dio.close(force: true);
    _localDio.close(force: true);
    super.dispose();
  }

  void _message(String text) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Flyer Chat'),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('确定'),
        ),
      ],
    ),
  );

  Future<void> _openApi() async {
    if (_busy) return;
    final id = _chatId.text.trim();
    final base = dotenv.env['FLYER_DEMO_BASE_URL'] ?? '';
    if (id.isEmpty || base.isEmpty) {
      _message('请填写 Chat ID，并在 .env 配置 FLYER_DEMO_BASE_URL。');
      return;
    }
    setState(() => _busy = true);
    try {
      final messages = await getInitialMessages(_dio, chatId: id);
      if (!mounted) return;
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => Api(
            currentUserId: _currentUserId,
            chatId: id,
            initialMessages: messages,
            dio: _dio,
          ),
        ),
      );
    } catch (e) {
      if (mounted) _message('Flyer API 示例请求失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateId() async {
    if ((dotenv.env['FLYER_DEMO_BASE_URL'] ?? '').isEmpty) {
      _message('请先配置 .env 中的 FLYER_DEMO_BASE_URL。');
      return;
    }
    try {
      final id = await getChatId(_dio);
      if (mounted) setState(() => _chatId.text = id);
    } catch (e) {
      if (mounted) _message('生成 Chat ID 失败：$e');
    }
  }

  Future<void> _openGemini() async {
    final controller = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: TextField(controller: controller, obscureText: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (key != null && key.isNotEmpty && mounted) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => Gemini(geminiApiKey: key)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Flyer Chat 示例')),
    body: !_ready
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const Text('消息发送者'),
              const SizedBox(height: 8),
              SegmentedButton<UserID>(
                segments: const [
                  ButtonSegment(value: 'john', label: Text('John')),
                  ButtonSegment(value: 'jane', label: Text('Jane')),
                ],
                selected: {_currentUserId},
                onSelectionChanged: (value) =>
                    setState(() => _currentUserId = value.first),
              ),
              const SizedBox(height: 20),
              const Text('REST API 示例'),
              const SizedBox(height: 8),
              TextField(
                controller: _chatId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Chat ID',
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _openApi,
                    child: Text(_busy ? '加载中…' : 'API 聊天'),
                  ),
                  OutlinedButton(
                    onPressed: _generateId,
                    child: const Text('生成 Chat ID'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: _chatId.text)),
                    child: const Text('复制 Chat ID'),
                  ),
                ],
              ),
              const Divider(height: 32),
              _ExampleEntry(
                title: 'Local / Hive 本地聊天',
                subtitle: '本地聊天、多类型消息与持久化示例',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => Local(dio: _localDio)),
                ),
              ),
              _ExampleEntry(
                title: 'Gemini AI 聊天',
                subtitle: '需要自行输入 Gemini API Key',
                onTap: _openGemini,
              ),
              _ExampleEntry(
                title: '分页：加载更早消息',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const PaginationOlder()),
                ),
              ),
              _ExampleEntry(
                title: '分页：加载更新消息',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const PaginationNewer()),
                ),
              ),
              _ExampleEntry(
                title: 'Basic 基础聊天',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => Basic()),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'API 示例需配置 Flyer 演示服务；不会自动连接 Friend/Tinode。',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
  );
}

class _ExampleEntry extends StatelessWidget {
  const _ExampleEntry({
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
