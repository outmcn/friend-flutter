class MatrixRoomViewData {
  const MatrixRoomViewData({
    required this.roomId,
    required this.title,
    required this.preview,
    this.timestamp,
    required this.unreadCount,
  });

  final String roomId;
  final String title;
  final String preview;
  final DateTime? timestamp;
  final int unreadCount;
}
