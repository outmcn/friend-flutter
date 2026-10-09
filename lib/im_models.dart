part of 'post_service.dart';

class DDConversation {
  const DDConversation({
    required this.id,
    required this.kind,
    this.peer,
    this.lastMessage,
    this.updatedAt,
    this.unreadCount = 0,
  });
  final String id;
  final String kind;
  final DDImPeer? peer;
  final DDImLastMessage? lastMessage;
  final String? updatedAt;
  final int unreadCount;

  factory DDConversation.fromJson(Map<String, dynamic> json) => DDConversation(
        id: '${json['id'] ?? ''}',
        kind: '${json['kind'] ?? 'dm'}',
        peer: json['peer'] is Map
            ? DDImPeer.fromJson((json['peer'] as Map).cast<String, dynamic>())
            : null,
        lastMessage: json['lastMessage'] is Map
            ? DDImLastMessage.fromJson(
                (json['lastMessage'] as Map).cast<String, dynamic>())
            : null,
        updatedAt: '${json['updatedAt'] ?? ''}',
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}

class DDImPeer {
  const DDImPeer(
      {required this.id,
      required this.nickname,
      this.avatarKey,
      this.avatarUrl});
  final String id;
  final String nickname;
  final String? avatarKey;
  final String? avatarUrl;

  factory DDImPeer.fromJson(Map<String, dynamic> json) => DDImPeer(
        id: '${json['id'] ?? ''}',
        nickname: '${json['nickname'] ?? json['username'] ?? '用户'}',
        avatarKey: json['avatarKey'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class DDImLastMessage {
  const DDImLastMessage({required this.text, required this.createdAt});
  final String text;
  final String createdAt;

  factory DDImLastMessage.fromJson(Map<String, dynamic> json) =>
      DDImLastMessage(
        text: '${json['text'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
      );
}

class DDImMessage {
  const DDImMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.kind,
    this.durationMs = 0,
    this.clientId,
    this.recalledAt,
    this.deletedAt,
  });
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String createdAt;
  final String kind;
  final int durationMs;
  final String? clientId;
  final String? recalledAt;
  final String? deletedAt;
  factory DDImMessage.fromJson(Map<String, dynamic> json) => DDImMessage(
        id: '${json['id'] ?? ''}',
        conversationId: '${json['conversationId'] ?? ''}',
        senderId: '${json['senderId'] ?? ''}',
        text: '${json['text'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
        kind: '${json['kind'] ?? 'text'}',
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        clientId: json['clientId'] as String?,
        recalledAt: json['recalledAt'] as String?,
        deletedAt: json['deletedAt'] as String?,
      );
}
