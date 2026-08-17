class ZenqivoPlaylist {
  const ZenqivoPlaylist({
    required this.id,
    required this.name,
    required this.type,
    required this.sourceUrl,
    required this.enabled,
    this.username,
    this.password,
  });

  final int id;
  final String name;
  final String type;
  final String sourceUrl;
  final bool enabled;
  final String? username;
  final String? password;

  bool get isXtream =>
      type.toLowerCase() == 'xtream' &&
      (username?.isNotEmpty ?? false) &&
      (password?.isNotEmpty ?? false);

  factory ZenqivoPlaylist.fromJson(Map<String, dynamic> json) {
    return ZenqivoPlaylist(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Playlist',
      type: json['type'] as String? ?? 'm3u',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      username: json['username'] as String?,
      password: json['password'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
