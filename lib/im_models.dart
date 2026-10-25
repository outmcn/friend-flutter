part of 'post_service.dart';

class DDConversation {
  const DDConversation({
    required this.id,
    required this.kind,
    this.peer,
    this.lastMessage,
    this.updatedAt,
    this.peerReadMessageId,
    this.mutationId,
    this.unreadCount = 0,
  });
  final String id;
  final String kind;
  final DDImPeer? peer;
  final DDImLastMessage? lastMessage;
  final String? updatedAt;
  final String? peerReadMessageId;
  final String? mutationId;
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
        peerReadMessageId: json['peerReadMessageId']?.toString(),
        mutationId: json['mutationId']?.toString(),
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}

class DDImPeer {
  const DDImPeer(
      {required this.id,
      required this.nickname,
      this.avatarKey,
      this.avatarUrl,
      this.avatarFrameAsset,
      this.avatarFrameSelection,
      this.online = false,
      this.latitude,
      this.longitude});
  final String id;
  final String nickname;
  final String? avatarKey;
  final String? avatarUrl;
  final String? avatarFrameAsset;
  final String? avatarFrameSelection;
  final bool online;
  final double? latitude;
  final double? longitude;

  factory DDImPeer.fromJson(Map<String, dynamic> json) => DDImPeer(
        id: '${json['id'] ?? ''}',
        nickname: '${json['nickname'] ?? json['username'] ?? '用户'}',
        avatarKey: json['avatarKey'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        avatarFrameAsset: json['avatarFrameAsset'] as String?,
        avatarFrameSelection: json['avatarFrameSelection'] as String?,
        online: json['online'] == true,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class DDImLastMessage {
  const DDImLastMessage({
    required this.text,
    this.kind = 'text',
    this.id,
    required this.createdAt,
    this.recalledAt,
    this.deletedAt,
    this.updatedAt,
    this.mutationId,
    this.metadata,
  });
  final String text;
  final String kind;
  final String? id;
  final String createdAt;
  final String? recalledAt;
  final String? deletedAt;
  final String? updatedAt;
  final String? mutationId;
  final Map<String, dynamic>? metadata;

  factory DDImLastMessage.fromJson(Map<String, dynamic> json) =>
      DDImLastMessage(
        text: '${json['text'] ?? ''}',
        kind: '${json['kind'] ?? 'text'}',
        id: json['id']?.toString(),
        createdAt: '${json['createdAt'] ?? ''}',
        recalledAt: json['recalledAt']?.toString(),
        deletedAt: json['deletedAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
        mutationId: json['mutationId']?.toString(),
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : null,
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
    this.metadata,
    this.clientId,
    this.recalledAt,
    this.deletedAt,
    this.updatedAt,
    this.mutationId,
  });
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String createdAt;
  final String kind;
  final int durationMs;
  final Map<String, dynamic>? metadata;
  final String? clientId;
  final String? recalledAt;
  final String? deletedAt;
  final String? updatedAt;
  final String? mutationId;
  factory DDImMessage.fromJson(Map<String, dynamic> json) => DDImMessage(
        id: '${json['id'] ?? ''}',
        conversationId: '${json['conversationId'] ?? ''}',
        senderId: '${json['senderId'] ?? ''}',
        text: '${json['text'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
        kind: '${json['kind'] ?? 'text'}',
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : null,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        clientId: json['clientId'] as String?,
        recalledAt: json['recalledAt'] as String?,
        deletedAt: json['deletedAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
        mutationId: json['mutationId'] as String?,
      );
}
