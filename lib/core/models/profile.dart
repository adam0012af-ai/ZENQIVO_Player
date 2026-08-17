class ZenqivoProfile {
  const ZenqivoProfile({
    required this.id,
    required this.name,
    required this.avatarIndex,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int avatarIndex;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarIndex': avatarIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ZenqivoProfile.fromJson(Map<String, dynamic> json) => ZenqivoProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Profile',
        avatarIndex: (json['avatarIndex'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
