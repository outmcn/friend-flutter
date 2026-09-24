class MatrixRoomViewData {
  const MatrixRoomViewData({
    required this.roomId,
    required this.title,
    required this.preview,
    required this.unreadCount,
  });

  final String roomId;
  final String title;
  final String preview;
  final int unreadCount;
}
