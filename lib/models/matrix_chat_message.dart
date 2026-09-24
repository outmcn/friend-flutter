class MatrixChatMessage {
  const MatrixChatMessage({
    required this.eventId,
    required this.senderId,
    required this.body,
    required this.isMine,
  });

  final String eventId;
  final String senderId;
  final String body;
  final bool isMine;
}
