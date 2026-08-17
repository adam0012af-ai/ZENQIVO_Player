import 'package:flutter/material.dart';

import '../../core/localization/zenqivo_strings.dart';

import '../../core/models/epg_program.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playlist.dart';
import '../../core/services/player_preferences_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import '../player/player_screen.dart';
import '../series/series_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.items,
    required this.epg,
    required this.playlists,
  });

  final List<MediaItem> items;
  final Map<String, List<EpgProgram>> epg;
  final List<ZenqivoPlaylist> playlists;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  String query = '';

  List<MediaItem> get results {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return widget.items.where((item) {
      final current = _currentProgram(item);
      return item.title.toLowerCase().contains(q) ||
          (item.group ?? '').toLowerCase().contains(q) ||
          (current?.title ?? '').toLowerCase().contains(q);
    }).take(120).toList();
  }

  EpgProgram? _currentProgram(MediaItem item) {
    final id = item.tvgId;
    if (id == null) return null;
    for (final p in widget.epg[id] ?? const <EpgProgram>[]) {
      if (p.isNow) return p;
    }
    return null;
  }

  Future<void> _open(MediaItem item) async {
    final prefs = PlayerPreferencesService();
    final settings = await prefs.load();
    if (settings.parentalEnabled && item.isAdult && mounted) {
      final ok = await _askPin(context, prefs);
      if (!ok || !mounted) return;
    }
    if (!mounted) return;

    if (item.isSeriesCollection) {
      ZenqivoPlaylist? playlist;
      for (final candidate in widget.playlists) {
        if (candidate.id == item.playlistId) {
          playlist = candidate;
          break;
        }
      }
      if (playlist == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SeriesDetailsScreen(series: item, playlist: playlist!),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final found = results;
    return Scaffold(
      appBar: AppBar(title: Text(ZText.t('البحث الشامل', 'Global Search'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(
            controller: controller,
            autofocus: true,
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: ZText.t('ابحث عن قناة، فيلم، مسلسل أو برنامج حالي...', 'Search channels, movies, series, or current programs...'),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: query.trim().isEmpty
                ? Center(child: Text(ZText.t('اكتب كلمة للبحث في كل المحتوى.', 'Type to search all content.'), style: const TextStyle(color: ZenqivoColors.muted)))
                : found.isEmpty
                    ? Center(child: Text(ZText.t('لا توجد نتائج.', 'No results found.'), style: const TextStyle(color: ZenqivoColors.muted)))
                    : ListView.separated(
                        itemCount: found.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = found[i];
                          final now = _currentProgram(item);
                          return ListTile(
                            onTap: () => _open(item),
                            leading: Icon(
                              item.kind == MediaKind.live
                                  ? Icons.live_tv_rounded
                                  : item.kind == MediaKind.movie
                                      ? Icons.movie_rounded
                                      : Icons.video_library_rounded,
                              color: ZenqivoColors.gold,
                            ),
                            title: Text(item.title),
                            subtitle: Text(
                              now?.title ?? item.group ?? _kindLabel(item.kind),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: item.isAdult
                                ? const Icon(Icons.lock_rounded, size: 18)
                                : const Icon(Icons.play_arrow_rounded),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  String _kindLabel(MediaKind kind) => switch (kind) {
        MediaKind.live => ZText.t('بث مباشر', 'Live TV'),
        MediaKind.movie => ZText.t('فيلم', 'Movie'),
        MediaKind.series => ZText.t('مسلسل', 'Series'),
      };
}

Future<bool> _askPin(BuildContext context, PlayerPreferencesService prefs) async {
  final pin = TextEditingController();
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(ZText.t('محتوى مقفول', 'Locked Content')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ZText.t('أدخل رمز الرقابة الأبوية للمتابعة.', 'Enter the parental PIN to continue.')),
            const SizedBox(height: 12),
            TextField(
              controller: pin,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              onSubmitted: (_) async {
                final ok = await prefs.verifyPin(pin.text);
                if (ok && context.mounted) Navigator.pop(context, true);
                if (!ok) setState(() => error = ZText.t('الرمز غير صحيح', 'Incorrect PIN'));
              },
            ),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ZText.t('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () async {
              final ok = await prefs.verifyPin(pin.text);
              if (ok && context.mounted) Navigator.pop(context, true);
              if (!ok) setState(() => error = ZText.t('الرمز غير صحيح', 'Incorrect PIN'));
            },
            child: Text(ZText.t('فتح', 'Unlock')),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
