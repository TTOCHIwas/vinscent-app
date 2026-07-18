import '../../../core/date/app_date_policy.dart';

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

enum CoupleAccessMode {
  pending,
  active,
  archivedReadOnly;

  factory CoupleAccessMode.fromJson(String value) {
    return switch (value) {
      'pending' => CoupleAccessMode.pending,
      'active' => CoupleAccessMode.active,
      'archived_read_only' => CoupleAccessMode.archivedReadOnly,
      _ => throw FormatException('Unknown couple access mode: $value'),
    };
  }
}

enum CoupleCharacterSetupStatus {
  pending,
  custom,
  defaultCharacter;

  factory CoupleCharacterSetupStatus.fromJson(String value) {
    return switch (value) {
      'pending' => CoupleCharacterSetupStatus.pending,
      'custom' => CoupleCharacterSetupStatus.custom,
      'default' => CoupleCharacterSetupStatus.defaultCharacter,
      _ => throw FormatException('Unknown character setup status: $value'),
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
    required this.accessMode,
    required this.createdAt,
    required this.updatedAt,
    this.characterSetupStatus = CoupleCharacterSetupStatus.custom,
    this.userBId,
    this.relationshipStartDate,
    this.connectedAt,
    this.disconnectedAt,
    this.disconnectedByUserId,
    this.archiveExpiresAt,
    this.currentDate,
  });

  factory Couple.fromJson(Map<String, dynamic> json) {
    final status = CoupleStatus.fromJson(json['status'] as String);

    return Couple(
      id: json['id'] as String,
      inviteCode: json['invite_code'] as String,
      userAId: json['user_a_id'] as String,
      userBId: json['user_b_id'] as String?,
      relationshipStartDate: _parseOptionalDate(
        json['relationship_start_date'] as String?,
      ),
      characterSetupStatus: CoupleCharacterSetupStatus.fromJson(
        json['character_setup_status'] as String? ?? 'custom',
      ),
      timezone: json['timezone'] as String,
      status: status,
      accessMode: _parseAccessMode(json['access_mode'] as String?, status),
      connectedAt: _parseOptionalDateTime(json['connected_at'] as String?),
      disconnectedAt: _parseOptionalDateTime(
        json['disconnected_at'] as String?,
      ),
      disconnectedByUserId: json['disconnected_by_user_id'] as String?,
      archiveExpiresAt: _parseOptionalDateTime(
        json['archive_expires_at'] as String?,
      ),
      currentDate: _parseOptionalDate(
        json['current_couple_date'] as String?,
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
  final CoupleCharacterSetupStatus characterSetupStatus;
  final String timezone;
  final CoupleStatus status;
  final CoupleAccessMode accessMode;
  final DateTime? connectedAt;
  final DateTime? disconnectedAt;
  final String? disconnectedByUserId;
  final DateTime? archiveExpiresAt;
  final DateTime? currentDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPending => accessMode == CoupleAccessMode.pending;

  bool get isActive => accessMode == CoupleAccessMode.active;

  bool get isArchivedReadOnly =>
      accessMode == CoupleAccessMode.archivedReadOnly;

  bool get canEditSharedData => isActive;

  bool get canReadSharedData => isActive || isArchivedReadOnly;

  bool get hasRelationshipStartDate => relationshipStartDate != null;

  bool get isCharacterSetupPending =>
      characterSetupStatus == CoupleCharacterSetupStatus.pending;

  bool get hasCustomCharacter =>
      characterSetupStatus == CoupleCharacterSetupStatus.custom;

  bool get needsCharacterSetupPrompt => isActive && !hasCustomCharacter;

  bool isInitialSetupOwner(String userId) =>
      isActive && userBId != null && userBId == userId;

  DateTime get effectiveCurrentDate => currentDate ?? currentAppDate();

  static CoupleAccessMode _parseAccessMode(
    String? value,
    CoupleStatus status,
  ) {
    if (value != null) {
      return CoupleAccessMode.fromJson(value);
    }

    return switch (status) {
      CoupleStatus.pending => CoupleAccessMode.pending,
      CoupleStatus.active => CoupleAccessMode.active,
      CoupleStatus.cancelled || CoupleStatus.disconnected =>
        CoupleAccessMode.archivedReadOnly,
    };
  }

  static DateTime? _parseOptionalDate(String? value) {
    if (value == null) {
      return null;
    }

    return calendarDateOnly(DateTime.parse(value));
  }

  static DateTime? _parseOptionalDateTime(String? value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value);
  }
}
