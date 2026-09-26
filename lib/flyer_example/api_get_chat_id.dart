import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final demoBaseUrl = dotenv.env['FLYER_DEMO_BASE_URL'] ?? '';

Future<String> getChatId(Dio dio) async {
  try {
    final response = await dio.post<Map<String, dynamic>>(
      '${demoBaseUrl}/chat',
    );

    final data = response.data?['chat_id'] as String? ?? '';

    return data;
  } catch (e) {
    rethrow;
  }
}
