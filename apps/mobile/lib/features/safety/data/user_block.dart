class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      blockedAt: DateTime.parse(json['blocked_at'] as String),
    );
  }

  final String userId;
  final String displayName;
  final DateTime blockedAt;

  @override
  bool operator ==(Object other) {
    return other is BlockedUser &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.blockedAt == blockedAt;
  }

  @override
  int get hashCode => Object.hash(userId, displayName, blockedAt);
}

class ReconnectableCoupleArchive {
  const ReconnectableCoupleArchive({
    required this.coupleId,
    required this.partnerUserId,
    required this.partnerDisplayName,
    required this.archiveExpiresAt,
  });

  factory ReconnectableCoupleArchive.fromJson(Map<String, dynamic> json) {
    return ReconnectableCoupleArchive(
      coupleId: json['couple_id'] as String,
      partnerUserId: json['partner_user_id'] as String,
      partnerDisplayName: json['partner_display_name'] as String,
      archiveExpiresAt: DateTime.parse(json['archive_expires_at'] as String),
    );
  }

  final String coupleId;
  final String partnerUserId;
  final String partnerDisplayName;
  final DateTime archiveExpiresAt;

  @override
  bool operator ==(Object other) {
    return other is ReconnectableCoupleArchive &&
        other.coupleId == coupleId &&
        other.partnerUserId == partnerUserId &&
        other.partnerDisplayName == partnerDisplayName &&
        other.archiveExpiresAt == archiveExpiresAt;
  }

  @override
  int get hashCode => Object.hash(
    coupleId,
    partnerUserId,
    partnerDisplayName,
    archiveExpiresAt,
  );
}
