import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class ApiClient {
  final String token;
  final String baseUrl;
  const ApiClient({
    required this.token,
    this.baseUrl = 'https://friend.outmcn.net',
  });

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> get(String path) =>
      _request(() => http.get(Uri.parse('$baseUrl$path'), headers: _headers));
  Future<Map<String, dynamic>> post(String path, {Object? body}) => _request(
    () => http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );
  Future<Map<String, dynamic>> put(String path, {Object? body}) => _request(
    () => http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );
  Future<Map<String, dynamic>> delete(String path) => _request(
    () => http.delete(Uri.parse('$baseUrl$path'), headers: _headers),
  );

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() call,
  ) async {
    final response = await call().timeout(const Duration(seconds: 15));
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('服务器返回格式无效', response.statusCode);
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw ApiException(
        decoded['message']?.toString() ?? '请求失败',
        response.statusCode,
      );
    }
    return decoded;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
