import 'package:flutter/material.dart';

import '../../core/localization/zenqivo_strings.dart';

import '../../core/models/media_item.dart';
import '../../core/services/player_preferences_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import '../player/player_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.items,
  });

  final List<MediaItem> items;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _prefs = PlayerPreferencesService();
  List<String> _recent = const [];
  Map<String, Duration> _progress = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recent = await _prefs.recentIds();
    final progress = await _prefs.allProgress();
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _progress = progress;
    });
  }

  List<MediaItem> get _recentItems {
    final byId = {for (final item in widget.items) item.id: item};
    return _recent.map((id) => byId[id]).whereType<MediaItem>().toList();
  }

  List<MediaItem> get _continueItems {
    final byId = {for (final item in widget.items) item.id: item};
    final values = <MediaItem>[];
    for (final id in _progress.keys) {
      final item = byId[id];
      if (item != null && item.kind != MediaKind.live) values.add(item);
    }
    values.sort((a, b) {
      final ai = _recent.indexOf(a.id);
      final bi = _recent.indexOf(b.id);
      return (ai < 0 ? 99999 : ai).compareTo(bi < 0 ? 99999 : bi);
    });
    return values;
  }

  Future<void> _open(MediaItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
    );
    await _load();
  }

  String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recentItems;
    final watching = _continueItems;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            ZText.watching,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.play_circle_outline_rounded,
            title: ZText.continueWatching,
          ),
          const SizedBox(height: 12),
          if (watching.isEmpty)
            _Empty(text: ZText.t('لا توجد عناصر غير مكتملة حتى الآن.', 'No unfinished items yet.'))
          else
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: watching.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = watching[index];
                  final pos = _progress[item.id] ?? Duration.zero;
                  return _HistoryCard(
                    item: item,
                    subtitle: ZText.t('توقفت عند ${_duration(pos)}', 'Stopped at ${_duration(pos)}'),
                    onTap: () => _open(item),
                  );
                },
              ),
            ),
          const SizedBox(height: 28),
          _SectionTitle(
            icon: Icons.history_rounded,
            title: ZText.recentlyWatched,
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            _Empty(text: ZText.t('لا يوجد سجل مشاهدة حتى الآن.', 'No watch history yet.'))
          else
            ...recent.map(
              (item) => Card(
                child: ListTile(
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
                  subtitle: Text(item.group ?? 'ZENQIVO'),
                  trailing: const Icon(Icons.play_arrow_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: ZenqivoColors.gold),
      const SizedBox(width: 9),
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZenqivoColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: ZenqivoColors.muted)),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.subtitle,
    required this.onTap,
  });

  final MediaItem item;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Material(
        color: ZenqivoColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                item.kind == MediaKind.movie
                    ? Icons.movie_rounded
                    : Icons.video_library_rounded,
                color: ZenqivoColors.gold,
                size: 38,
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: ZenqivoColors.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}
