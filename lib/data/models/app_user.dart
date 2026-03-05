class AppUser {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final bool isAnonymous;
  final String plan;
  final int usageMinMonth;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.isAnonymous = true,
    this.plan = 'free',
    this.usageMinMonth = 0,
    required this.createdAt,
  });

  bool get isFree => plan == 'free';
  bool get isPro => plan == 'pro';

  int get maxRecordingMinutes => isPro ? 60 : 15;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? true,
      plan: json['plan'] as String? ?? 'free',
      usageMinMonth: json['usage_min_month'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'is_anonymous': isAnonymous,
      'plan': plan,
      'usage_min_month': usageMinMonth,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? displayName,
    String? avatarUrl,
    bool? isAnonymous,
    String? plan,
    int? usageMinMonth,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      plan: plan ?? this.plan,
      usageMinMonth: usageMinMonth ?? this.usageMinMonth,
      createdAt: createdAt,
    );
  }
}
