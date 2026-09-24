class MatrixBridgeSession {
  const MatrixBridgeSession({
    required this.userId,
    required this.deviceId,
    required this.accessToken,
  });

  final String userId;
  final String deviceId;
  final String accessToken;

  factory MatrixBridgeSession.fromJson(Map<String, dynamic> json) {
    return MatrixBridgeSession(
      userId: json['userId'] as String,
      deviceId: json['deviceId'] as String,
      accessToken: json['accessToken'] as String,
    );
  }
}
