import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../config/zenqivo_config.dart';
import '../models/epg_program.dart';

class EpgLoadResult {
  const EpgLoadResult({
    required this.programs,
    this.failedUrls = const [],
    this.usedStaleCache = false,
  });

  final Map<String, List<EpgProgram>> programs;
  final List<String> failedUrls;
  final bool usedStaleCache;
}

class _EpgCacheEntry {
  const _EpgCacheEntry({
    required this.programs,
    required this.savedAt,
  });

  final Map<String, List<EpgProgram>> programs;
  final DateTime savedAt;

  bool get fresh =>
      DateTime.now().difference(savedAt) < const Duration(minutes: 15);
}

class EpgService {
  EpgService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Map<String, _EpgCacheEntry> _cache = {};

  Future<EpgLoadResult> load(
    List<String> urls, {
    bool forceRefresh = false,
  }) async {
    _pruneCache();
    final unique = urls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (unique.isEmpty) {
      return const EpgLoadResult(programs: {});
    }

    final parts = await Future.wait(
      unique.map(
        (url) => _loadOne(
          url,
          forceRefresh: forceRefresh,
        ),
      ),
    );

    final result = <String, List<EpgProgram>>{};
    final failures = <String>[];
    var stale = false;

    for (final part in parts) {
      if (part.failed) failures.add(part.url);
      if (part.usedStaleCache) stale = true;

      for (final entry in part.programs.entries) {
        result.putIfAbsent(entry.key, () => <EpgProgram>[])
          ..addAll(entry.value);
      }
    }

    for (final programs in result.values) {
      programs.sort((a, b) => a.start.compareTo(b.start));
    }

    return EpgLoadResult(
      programs: result,
      failedUrls: failures,
      usedStaleCache: stale,
    );
  }

  void _pruneCache() {
    if (_cache.length <= 16) return;
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.savedAt.compareTo(b.value.savedAt));
    for (final entry in entries.take(_cache.length - 16)) {
      _cache.remove(entry.key);
    }
  }

  Future<_EpgPart> _loadOne(
    String url, {
    required bool forceRefresh,
  }) async {
    final cached = _cache[url];

    if (!forceRefresh && cached != null && cached.fresh) {
      return _EpgPart(
        url: url,
        programs: cached.programs,
        failed: false,
        usedStaleCache: false,
      );
    }

    try {
      final programs = await _fetch(url);
      _cache[url] = _EpgCacheEntry(
        programs: programs,
        savedAt: DateTime.now(),
      );

      return _EpgPart(
        url: url,
        programs: programs,
        failed: false,
        usedStaleCache: false,
      );
    } catch (_) {
      if (cached != null) {
        return _EpgPart(
          url: url,
          programs: cached.programs,
          failed: true,
          usedStaleCache: true,
        );
      }

      return _EpgPart(
        url: url,
        programs: const {},
        failed: true,
        usedStaleCache: false,
      );
    }
  }

  Future<Map<String, List<EpgProgram>>> _fetch(String url) async {
    final response = await _client
        .get(
          Uri.parse(url),
          headers: const {
            'accept': 'application/xml,text/xml,*/*',
            'user-agent': ZenqivoConfig.userAgent,
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('epg_http_${response.statusCode}');
    }

    final document = XmlDocument.parse(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );

    final result = <String, List<EpgProgram>>{};

    for (final node in document.findAllElements('programme')) {
      final channel = node.getAttribute('channel');
      final start = _parseXmltvDate(node.getAttribute('start'));
      final stop = _parseXmltvDate(node.getAttribute('stop'));

      if (channel == null || start == null || stop == null) continue;

      final titleNodes = node.findElements('title');
      if (titleNodes.isEmpty) continue;

      final title = titleNodes.first.innerText.trim();
      if (title.isEmpty) continue;

      final descriptions = node.findElements('desc');

      result.putIfAbsent(channel, () => <EpgProgram>[]).add(
            EpgProgram(
              channelId: channel,
              title: title,
              start: start,
              stop: stop,
              description: descriptions.isEmpty
                  ? null
                  : descriptions.first.innerText.trim(),
            ),
          );
    }

    return result;
  }

  DateTime? _parseXmltvDate(String? raw) {
    if (raw == null || raw.length < 14) return null;

    try {
      final dt = DateTime.utc(
        int.parse(raw.substring(0, 4)),
        int.parse(raw.substring(4, 6)),
        int.parse(raw.substring(6, 8)),
        int.parse(raw.substring(8, 10)),
        int.parse(raw.substring(10, 12)),
        int.parse(raw.substring(12, 14)),
      );

      final offset =
          RegExp(r'([+-])(\d{2})(\d{2})').firstMatch(raw.substring(14));

      if (offset == null) return dt.toLocal();

      final mins =
          int.parse(offset.group(2)!) * 60 + int.parse(offset.group(3)!);

      final adjusted = offset.group(1) == '+'
          ? dt.subtract(Duration(minutes: mins))
          : dt.add(Duration(minutes: mins));

      return adjusted.toLocal();
    } catch (_) {
      return null;
    }
  }
}

class _EpgPart {
  const _EpgPart({
    required this.url,
    required this.programs,
    required this.failed,
    required this.usedStaleCache,
  });

  final String url;
  final Map<String, List<EpgProgram>> programs;
  final bool failed;
  final bool usedStaleCache;
}
