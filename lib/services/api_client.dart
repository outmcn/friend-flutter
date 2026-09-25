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

  Future<Map<String, dynamic>> getMatrixSession() => get('/api/matrix/session');

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() call,
  ) async {
    late final http.Response response;
    try {
      response = await call().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException('请求超时，请稍后重试', 408);
    } on http.ClientException {
      throw const ApiException('网络连接失败，请检查网络', 0);
    }
    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(response.body);
      decoded = value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
    } catch (_) {
      throw ApiException('服务器返回格式无效', response.statusCode);
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw ApiException(
        decoded['message']?.toString() ??
            (response.statusCode == 429 ? '服务暂时限流，请稍后重试' : '请求失败'),
        response.statusCode,
        retryAfter: int.tryParse(response.headers['retry-after'] ?? ''),
      );
    }
    return decoded;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final int? retryAfter;
  const ApiException(this.message, this.statusCode, {this.retryAfter});
  @override
  String toString() => message;
}
