class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.birthDate,
    required this.onboardingCompletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      birthDate: DateTime.parse(json['birth_date'] as String),
      avatarUrl: json['avatar_url'] as String?,
      onboardingCompletedAt: DateTime.parse(
        json['onboarding_completed_at'] as String,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String displayName;
  final DateTime birthDate;
  final String? avatarUrl;
  final DateTime onboardingCompletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
