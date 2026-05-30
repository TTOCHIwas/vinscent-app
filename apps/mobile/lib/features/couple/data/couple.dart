enum CoupleStatus {
  pending,
  active,
  cancelled,
  disconnected;

  factory CoupleStatus.fromJson(String value) {
    return switch (value) {
      'pending' => CoupleStatus.pending,
      'active' => CoupleStatus.active,
      'cancelled' => CoupleStatus.cancelled,
      'disconnected' => CoupleStatus.disconnected,
      _ => throw FormatException('Unknown couple status: $value'),
    };
  }
}

class Couple {
  const Couple({
    required this.id,
    required this.inviteCode,
    required this.userAId,
    required this.timezone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userBId,
    this.relationshipStartDate,
    this.connectedAt,
    this.disconnectedAt,
  });

  factory Couple.fromJson(Map<String, dynamic> json) {
    return Couple(
      id: json['id'] as String,
      inviteCode: json['invite_code'] as String,
      userAId: json['user_a_id'] as String,
      userBId: json['user_b_id'] as String?,
      relationshipStartDate: _parseOptionalDate(
        json['relationship_start_date'] as String?,
      ),
      timezone: json['timezone'] as String,
      status: CoupleStatus.fromJson(json['status'] as String),
      connectedAt: _parseOptionalDateTime(json['connected_at'] as String?),
      disconnectedAt: _parseOptionalDateTime(
        json['disconnected_at'] as String?,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String inviteCode;
  final String userAId;
  final String? userBId;
  final DateTime? relationshipStartDate;
  final String timezone;
  final CoupleStatus status;
  final DateTime? connectedAt;
  final DateTime? disconnectedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPending => status == CoupleStatus.pending;

  bool get isActive => status == CoupleStatus.active;

  bool get hasRelationshipStartDate => relationshipStartDate != null;

  static DateTime? _parseOptionalDate(String? value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value);
  }

  static DateTime? _parseOptionalDateTime(String? value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value);
  }
}
