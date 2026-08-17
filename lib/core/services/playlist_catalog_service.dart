import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/zenqivo_config.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import 'xtream_service.dart';

class PlaylistCatalogResult {
  const PlaylistCatalogResult({
    required this.items,
    required this.epgUrls,
    this.failedSources = const [],
    this.usedStaleCache = false,
  });

  final List<MediaItem> items;
  final List<String> epgUrls;
  final List<String> failedSources;
  final bool usedStaleCache;
}

class _CatalogCacheEntry {
  const _CatalogCacheEntry({
    required this.result,
    required this.savedAt,
  });

  final PlaylistCatalogResult result;
  final DateTime savedAt;

  bool get fresh =>
      DateTime.now().difference(savedAt) < const Duration(minutes: 10);
}

class PlaylistCatalogService {
  PlaylistCatalogService({http.Client? client})
      : _client = client ?? http.Client(),
        _xtream = XtreamService(client: client);

  final http.Client _client;
  final XtreamService _xtream;

  static final Map<String, _CatalogCacheEntry> _cache = {};

  Future<PlaylistCatalogResult> load(
    List<ZenqivoPlaylist> playlists, {
    bool forceRefresh = false,
  }) async {
    _pruneCache();
    final enabled = playlists.where((p) => p.enabled).toList(growable: false);
    if (enabled.isEmpty) {
      return const PlaylistCatalogResult(items: [], epgUrls: []);
    }

    final parts = await Future.wait(
      enabled.map(
        (playlist) => _loadOne(
          playlist,
          forceRefresh: forceRefresh,
        ),
      ),
    );

    final items = <MediaItem>[];
    final epgUrls = <String>[];
    final failures = <String>[];
    var usedStale = false;

    for (final part in parts) {
      items.addAll(part.result.items);
      epgUrls.addAll(part.result.epgUrls);
      if (part.failed) failures.add(part.name);
      if (part.usedStaleCache) usedStale = true;
    }

    return PlaylistCatalogResult(
      items: items,
      epgUrls: epgUrls.toSet().toList(growable: false),
      failedSources: failures,
      usedStaleCache: usedStale,
    );
  }

  void _pruneCache() {
    if (_cache.length <= 24) return;
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.savedAt.compareTo(b.value.savedAt));
    for (final entry in entries.take(_cache.length - 24)) {
      _cache.remove(entry.key);
    }
  }

  Future<_CatalogPart> _loadOne(
    ZenqivoPlaylist playlist, {
    required bool forceRefresh,
  }) async {
    final key = _cacheKey(playlist);
    final cached = _cache[key];

    if (!forceRefresh && cached != null && cached.fresh) {
      return _CatalogPart(
        name: playlist.name,
        result: cached.result,
        failed: false,
        usedStaleCache: false,
      );
    }

    try {
      final result = await _fetch(playlist);
      _cache[key] = _CatalogCacheEntry(
        result: result,
        savedAt: DateTime.now(),
      );
      return _CatalogPart(
        name: playlist.name,
        result: result,
        failed: false,
        usedStaleCache: false,
      );
    } catch (_) {
      if (cached != null) {
        return _CatalogPart(
          name: playlist.name,
          result: cached.result,
          failed: true,
          usedStaleCache: true,
        );
      }

      return _CatalogPart(
        name: playlist.name,
        result: const PlaylistCatalogResult(items: [], epgUrls: []),
        failed: true,
        usedStaleCache: false,
      );
    }
  }

  Future<PlaylistCatalogResult> _fetch(ZenqivoPlaylist playlist) async {
    if (playlist.isXtream) {
      final parsed = await _xtream.loadCatalog(playlist);
      return PlaylistCatalogResult(
        items: parsed.items,
        epgUrls: parsed.epgUrls,
      );
    }

    if (playlist.type.toLowerCase() != 'm3u' || playlist.sourceUrl.isEmpty) {
      return const PlaylistCatalogResult(items: [], epgUrls: []);
    }

    final response = await _client
        .get(
          Uri.parse(playlist.sourceUrl),
          headers: const {
            'accept': '*/*',
            'user-agent': ZenqivoConfig.userAgent,
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('m3u_http_${response.statusCode}');
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    return _parseM3u(body, playlist.id);
  }

  String _cacheKey(ZenqivoPlaylist playlist) => [
        playlist.id,
        playlist.type,
        playlist.sourceUrl,
        playlist.username ?? '',
      ].join('|');

  PlaylistCatalogResult _parseM3u(String body, int playlistId) {
    final lines = const LineSplitter().convert(body);
    final items = <MediaItem>[];
    final epgUrls = <String>[];

    if (lines.isNotEmpty && lines.first.startsWith('#EXTM3U')) {
      final header = lines.first;
      final epgMatch = RegExp(
        r'''(?:x-tvg-url|url-tvg)=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(header);
      if (epgMatch != null) {
        epgUrls.addAll(
          epgMatch
              .group(1)!
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }
    }

    String? extinf;
    var index = 0;

    for (final raw in lines) {
      final line = raw.trim();

      if (line.startsWith('#EXTINF:')) {
        extinf = line;
        continue;
      }

      if (extinf == null || line.isEmpty || line.startsWith('#')) continue;

      final title = extinf!.contains(',')
          ? extinf!.split(',').last.trim()
          : 'Media';

      final attrs = <String, String>{};
      for (final match
          in RegExp(r'''([\w-]+)=["']([^"']*)["']''').allMatches(extinf!)) {
        attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
      }

      final group = attrs['group-title'] ?? '';
      final combined = '$group $title $line'.toLowerCase();
      final kind = _kind(combined);
      final adult = RegExp(
        r'\b(adult|xxx|18\+|18 plus|للكبار)\b',
        caseSensitive: false,
      ).hasMatch(combined);

      items.add(
        MediaItem(
          id: '$playlistId-${attrs['tvg-id'] ?? index}-$index',
          title: title,
          streamUrl: line,
          kind: kind,
          playlistId: playlistId,
          logoUrl: attrs['tvg-logo'],
          group: group.isEmpty ? null : group,
          tvgId: attrs['tvg-id'],
          isAdult: adult,
        ),
      );

      index++;
      extinf = null;
    }

    return PlaylistCatalogResult(
      items: items,
      epgUrls: epgUrls,
    );
  }

  MediaKind _kind(String value) {
    if (RegExp(r'\b(series|season|episode|مسلسلات|مسلسل)\b')
        .hasMatch(value)) {
      return MediaKind.series;
    }

    if (RegExp(r'\b(movie|movies|vod|film|cinema|أفلام|فيلم)\b')
        .hasMatch(value)) {
      return MediaKind.movie;
    }

    return MediaKind.live;
  }
}

class _CatalogPart {
  const _CatalogPart({
    required this.name,
    required this.result,
    required this.failed,
    required this.usedStaleCache,
  });

  final String name;
  final PlaylistCatalogResult result;
  final bool failed;
  final bool usedStaleCache;
}
