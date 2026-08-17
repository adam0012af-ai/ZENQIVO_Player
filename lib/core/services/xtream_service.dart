import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/zenqivo_config.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/series_episode.dart';

class XtreamCatalogResult {
  const XtreamCatalogResult({
    required this.items,
    required this.epgUrls,
  });

  final List<MediaItem> items;
  final List<String> epgUrls;
}


class _SeriesCacheEntry {
  const _SeriesCacheEntry({
    required this.episodes,
    required this.savedAt,
  });

  final List<SeriesEpisode> episodes;
  final DateTime savedAt;

  bool get fresh =>
      DateTime.now().difference(savedAt) < const Duration(minutes: 10);
}

class XtreamService {
  XtreamService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Map<String, _SeriesCacheEntry> _seriesCache = {};

  Future<XtreamCatalogResult> loadCatalog(ZenqivoPlaylist playlist) async {
    if (!playlist.isXtream) {
      return const XtreamCatalogResult(items: [], epgUrls: []);
    }

    final base = _base(playlist.sourceUrl);
    final username = playlist.username!;
    final password = playlist.password!;

    final liveCategoriesFuture =
        _categories(base, username, password, 'get_live_categories');
    final vodCategoriesFuture =
        _categories(base, username, password, 'get_vod_categories');
    final seriesCategoriesFuture =
        _categories(base, username, password, 'get_series_categories');

    final liveFuture = _list(base, username, password, 'get_live_streams');
    final vodFuture = _list(base, username, password, 'get_vod_streams');
    final seriesFuture = _list(base, username, password, 'get_series');

    final liveCategories = await liveCategoriesFuture;
    final vodCategories = await vodCategoriesFuture;
    final seriesCategories = await seriesCategoriesFuture;
    final live = await liveFuture;
    final vod = await vodFuture;
    final series = await seriesFuture;

    final items = <MediaItem>[
      ...live.map((e) => _liveItem(playlist.id, base, username, password, e, liveCategories)),
      ...vod.map((e) => _vodItem(playlist.id, base, username, password, e, vodCategories)),
      ...series.map((e) => _seriesItem(playlist.id, e, seriesCategories)),
    ];

    final xmltv = Uri.parse('$base/xmltv.php').replace(queryParameters: {
      'username': username,
      'password': password,
    }).toString();

    return XtreamCatalogResult(items: items, epgUrls: [xmltv]);
  }

  Future<List<SeriesEpisode>> loadSeriesEpisodes(
    ZenqivoPlaylist playlist,
    int seriesId, {
    bool forceRefresh = false,
  }) async {
    if (!playlist.isXtream) return const [];

    final key = '${playlist.id}|$seriesId';
    final cached = _seriesCache[key];

    if (!forceRefresh && cached != null && cached.fresh) {
      return cached.episodes;
    }

    try {
      final episodes = await _fetchSeriesEpisodes(playlist, seriesId);
      _seriesCache[key] = _SeriesCacheEntry(
        episodes: episodes,
        savedAt: DateTime.now(),
      );
      return episodes;
    } catch (_) {
      if (cached != null) return cached.episodes;
      rethrow;
    }
  }

  Future<List<SeriesEpisode>> _fetchSeriesEpisodes(
    ZenqivoPlaylist playlist,
    int seriesId,
  ) async {
    final base = _base(playlist.sourceUrl);
    final uri = Uri.parse('$base/player_api.php').replace(queryParameters: {
      'username': playlist.username!,
      'password': playlist.password!,
      'action': 'get_series_info',
      'series_id': '$seriesId',
    });

    final response = await _client
        .get(
          uri,
          headers: const {
            'accept': 'application/json,*/*',
            'user-agent': ZenqivoConfig.userAgent,
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('xtream_series_failed_${response.statusCode}');
    }

    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (decoded is! Map<String, dynamic>) return const [];

    final episodesRaw = decoded['episodes'];
    if (episodesRaw is! Map) return const [];

    final result = <SeriesEpisode>[];

    for (final entry in episodesRaw.entries) {
      final season = int.tryParse(entry.key.toString()) ?? 0;
      final list = entry.value;
      if (list is! List) continue;

      for (final raw in list) {
        if (raw is! Map) continue;

        final e = Map<String, dynamic>.from(raw);
        final id = '${e['id'] ?? ''}';
        if (id.isEmpty) continue;

        final ext = '${e['container_extension'] ?? 'mp4'}';
        final episodeNum =
            int.tryParse('${e['episode_num'] ?? e['episode'] ?? 0}') ?? 0;
        final title = '${e['title'] ?? 'Episode $episodeNum'}';
        final streamUrl =
            '$base/series/${playlist.username}/${playlist.password}/$id.$ext';

        result.add(
          SeriesEpisode(
            id: id,
            title: title,
            episodeNumber: episodeNum,
            season: season,
            streamUrl: streamUrl,
            containerExtension: ext,
            info: e['info'] is Map
                ? Map<String, dynamic>.from(e['info'])
                : null,
          ),
        );
      }
    }

    result.sort((a, b) {
      final bySeason = a.season.compareTo(b.season);
      return bySeason != 0
          ? bySeason
          : a.episodeNumber.compareTo(b.episodeNumber);
    });

    return result;
  }

  Future<Map<String, String>> _categories(
    String base,
    String username,
    String password,
    String action,
  ) async {
    try {
      final list = await _list(base, username, password, action);
      return {
        for (final e in list)
          '${e['category_id'] ?? ''}': '${e['category_name'] ?? 'Other'}',
      };
    } catch (_) {
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> _list(
    String base,
    String username,
    String password,
    String action,
  ) async {
    final uri = Uri.parse('$base/player_api.php').replace(queryParameters: {
      'username': username,
      'password': password,
      'action': action,
    });
    final response = await _client
        .get(
          uri,
          headers: const {
            'accept': 'application/json,*/*',
            'user-agent': ZenqivoConfig.userAgent,
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('xtream_${action}_failed_${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  MediaItem _liveItem(
    int playlistId,
    String base,
    String username,
    String password,
    Map<String, dynamic> e,
    Map<String, String> categories,
  ) {
    final id = '${e['stream_id'] ?? ''}';
    final categoryId = '${e['category_id'] ?? ''}';
    final ext = '${e['container_extension'] ?? 'ts'}';
    final title = '${e['name'] ?? 'Live'}';

    return MediaItem(
      id: 'xt-live-$id',
      title: title,
      streamUrl: '$base/live/$username/$password/$id.$ext',
      kind: MediaKind.live,
      playlistId: playlistId,
      logoUrl: _text(e['stream_icon']),
      group: categories[categoryId],
      tvgId: _text(e['epg_channel_id']),
      categoryId: categoryId,
      containerExtension: ext,
      isAdult: _adult('${categories[categoryId] ?? ''} $title'),
    );
  }

  MediaItem _vodItem(
    int playlistId,
    String base,
    String username,
    String password,
    Map<String, dynamic> e,
    Map<String, String> categories,
  ) {
    final id = '${e['stream_id'] ?? ''}';
    final categoryId = '${e['category_id'] ?? ''}';
    final ext = '${e['container_extension'] ?? 'mp4'}';
    final title = '${e['name'] ?? 'Movie'}';

    return MediaItem(
      id: 'xt-vod-$id',
      title: title,
      streamUrl: '$base/movie/$username/$password/$id.$ext',
      kind: MediaKind.movie,
      playlistId: playlistId,
      logoUrl: _text(e['stream_icon']),
      group: categories[categoryId],
      categoryId: categoryId,
      containerExtension: ext,
      description: _text(e['plot'] ?? e['description']),
      year: _text(e['year'] ?? e['releaseDate'] ?? e['release_date']),
      rating: _text(e['rating'] ?? e['rating_5based']),
      isAdult: _adult('${categories[categoryId] ?? ''} $title'),
    );
  }

  MediaItem _seriesItem(
    int playlistId,
    Map<String, dynamic> e,
    Map<String, String> categories,
  ) {
    final seriesId = int.tryParse('${e['series_id'] ?? ''}');
    final categoryId = '${e['category_id'] ?? ''}';
    final title = '${e['name'] ?? 'Series'}';

    return MediaItem(
      id: 'xt-series-${seriesId ?? title.hashCode}',
      title: title,
      streamUrl: '',
      kind: MediaKind.series,
      playlistId: playlistId,
      logoUrl: _text(e['cover']),
      group: categories[categoryId],
      seriesId: seriesId,
      categoryId: categoryId,
      description: _text(e['plot']),
      year: _text(e['releaseDate'] ?? e['release_date']),
      rating: _text(e['rating']),
      isAdult: _adult('${categories[categoryId] ?? ''} $title'),
    );
  }

  String _base(String source) {
    final trimmed = source.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/player_api.php')) {
      return trimmed.substring(0, trimmed.length - '/player_api.php'.length);
    }
    return trimmed;
  }

  String? _text(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  bool _adult(String value) =>
      RegExp(r'\b(adult|xxx|18\+|18 plus|للكبار)\b', caseSensitive: false)
          .hasMatch(value.toLowerCase());
}
