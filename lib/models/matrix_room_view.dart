class MatrixRoomViewData {
  const MatrixRoomViewData({
    required this.roomId,
    required this.title,
    required this.preview,
    this.timestamp,
    required this.unreadCount,
    this.avatarId = 0,
    this.pinned = false,
    this.muted = false,
  });

  final String roomId;
  final String title;
  final String preview;
  final DateTime? timestamp;
  final int unreadCount;
  final int avatarId;
  final bool pinned;
  final bool muted;
}
