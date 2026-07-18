import 'package:vinscent/features/couple/data/couple.dart';

Couple pendingCouple({
  String id = 'couple-id',
  String inviteCode = 'ABC234',
  String userAId = 'user-id',
  String timezone = 'Asia/Seoul',
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? currentDate,
}) {
  return _buildCouple(
    id: id,
    inviteCode: inviteCode,
    userAId: userAId,
    timezone: timezone,
    status: CoupleStatus.pending,
    accessMode: CoupleAccessMode.pending,
    characterSetupStatus: CoupleCharacterSetupStatus.pending,
    createdAt: createdAt,
    updatedAt: updatedAt,
    currentDate: currentDate,
  );
}

Couple activeCouple({
  String id = 'couple-id',
  String inviteCode = 'ABC234',
  String userAId = 'user-id',
  String userBId = 'partner-id',
  DateTime? relationshipStartDate,
  String timezone = 'Asia/Seoul',
  DateTime? connectedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? currentDate,
  CoupleCharacterSetupStatus characterSetupStatus =
      CoupleCharacterSetupStatus.custom,
}) {
  final createdAtValue = createdAt ?? DateTime(2026);

  return _buildCouple(
    id: id,
    inviteCode: inviteCode,
    userAId: userAId,
    userBId: userBId,
    relationshipStartDate: relationshipStartDate ?? DateTime(2026, 5, 30),
    timezone: timezone,
    status: CoupleStatus.active,
    accessMode: CoupleAccessMode.active,
    characterSetupStatus: characterSetupStatus,
    connectedAt: connectedAt ?? createdAtValue,
    createdAt: createdAtValue,
    updatedAt: updatedAt,
    currentDate: currentDate,
  );
}

Couple activeCoupleWithoutDate({
  String id = 'couple-id',
  String inviteCode = 'ABC234',
  String userAId = 'user-id',
  String userBId = 'partner-id',
  String timezone = 'Asia/Seoul',
  DateTime? connectedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? currentDate,
  CoupleCharacterSetupStatus characterSetupStatus =
      CoupleCharacterSetupStatus.pending,
}) {
  final createdAtValue = createdAt ?? DateTime(2026);

  return _buildCouple(
    id: id,
    inviteCode: inviteCode,
    userAId: userAId,
    userBId: userBId,
    timezone: timezone,
    status: CoupleStatus.active,
    accessMode: CoupleAccessMode.active,
    characterSetupStatus: characterSetupStatus,
    connectedAt: connectedAt ?? createdAtValue,
    createdAt: createdAtValue,
    updatedAt: updatedAt,
    currentDate: currentDate,
  );
}

Couple archivedReadOnlyCouple({
  String id = 'couple-id',
  String inviteCode = 'ABC234',
  String userAId = 'user-id',
  String userBId = 'partner-id',
  DateTime? relationshipStartDate,
  String timezone = 'Asia/Seoul',
  DateTime? connectedAt,
  DateTime? disconnectedAt,
  String? disconnectedByUserId,
  DateTime? archiveExpiresAt,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? currentDate,
  CoupleCharacterSetupStatus characterSetupStatus =
      CoupleCharacterSetupStatus.custom,
}) {
  final createdAtValue = createdAt ?? DateTime(2026);
  final disconnectedAtValue = disconnectedAt ?? DateTime(2026, 6, 1);

  return _buildCouple(
    id: id,
    inviteCode: inviteCode,
    userAId: userAId,
    userBId: userBId,
    relationshipStartDate: relationshipStartDate ?? DateTime(2026, 5, 30),
    timezone: timezone,
    status: CoupleStatus.disconnected,
    accessMode: CoupleAccessMode.archivedReadOnly,
    characterSetupStatus: characterSetupStatus,
    connectedAt: connectedAt ?? createdAtValue,
    disconnectedAt: disconnectedAtValue,
    disconnectedByUserId: disconnectedByUserId ?? userAId,
    archiveExpiresAt:
        archiveExpiresAt ?? disconnectedAtValue.add(const Duration(days: 30)),
    createdAt: createdAtValue,
    updatedAt: updatedAt,
    currentDate: currentDate,
  );
}

Couple _buildCouple({
  required String id,
  required String inviteCode,
  required String userAId,
  required String timezone,
  required CoupleStatus status,
  required CoupleAccessMode accessMode,
  CoupleCharacterSetupStatus characterSetupStatus =
      CoupleCharacterSetupStatus.custom,
  String? userBId,
  DateTime? relationshipStartDate,
  DateTime? connectedAt,
  DateTime? disconnectedAt,
  String? disconnectedByUserId,
  DateTime? archiveExpiresAt,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? currentDate,
}) {
  final createdAtValue = createdAt ?? DateTime(2026);

  return Couple(
    id: id,
    inviteCode: inviteCode,
    userAId: userAId,
    userBId: userBId,
    relationshipStartDate: relationshipStartDate,
    timezone: timezone,
    status: status,
    accessMode: accessMode,
    characterSetupStatus: characterSetupStatus,
    connectedAt: connectedAt,
    disconnectedAt: disconnectedAt,
    disconnectedByUserId: disconnectedByUserId,
    archiveExpiresAt: archiveExpiresAt,
    currentDate: currentDate,
    createdAt: createdAtValue,
    updatedAt: updatedAt ?? createdAtValue,
  );
}
