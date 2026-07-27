import '../../../core/date/app_date_policy.dart';

enum CoupleMemberRole {
  self,
  partner;

  factory CoupleMemberRole.fromJson(String value) {
    return switch (value) {
      'self' => CoupleMemberRole.self,
      'partner' => CoupleMemberRole.partner,
      _ => throw FormatException('Unknown couple member role: $value'),
    };
  }
}

class CoupleMemberBirthday {
  const CoupleMemberBirthday({required this.role, required this.birthDate});

  factory CoupleMemberBirthday.fromJson(Map<String, dynamic> json) {
    return CoupleMemberBirthday(
      role: CoupleMemberRole.fromJson(json['member_role'] as String),
      birthDate: calendarDateOnly(DateTime.parse(json['birth_date'] as String)),
    );
  }

  final CoupleMemberRole role;
  final DateTime birthDate;
}
