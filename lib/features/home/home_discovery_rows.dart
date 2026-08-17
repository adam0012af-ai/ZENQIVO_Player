import 'package:flutter/material.dart';

import '../../core/localization/zenqivo_strings.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playlist.dart';
import '../../core/services/player_preferences_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import '../movie/movie_details_screen.dart';
import '../player/player_screen.dart';
import '../series/series_details_screen.dart';

class HomeDiscoveryRows extends StatefulWidget {
  const HomeDiscoveryRows({
    super.key,
    required this.items,
    required this.playlists,
  });

  final List<MediaItem> items;
  final List<ZenqivoPlaylist> playlists;

  @override
  State<HomeDiscoveryRows> createState() => _HomeDiscoveryRowsState();
}

class _HomeDiscoveryRowsState extends State<HomeDiscoveryRows> {
  final _prefs = PlayerPreferencesService();
  List<String> _recentIds = const [];
  Set<String> _favoriteIds = {};
  Map<String, Duration> _progress = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeDiscoveryRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) _load();
  }

  Future<void> _load() async {
    final recent = await _prefs.recentIds();
    final favorites = await _prefs.favorites();
    final progress = await _prefs.allProgress();
    if (!mounted) return;
    setState(() {
      _recentIds = recent;
      _favoriteIds = favorites;
      _progress = progress;
    });
  }

  Map<String, MediaItem> get _byId => {
        for (final item in widget.items) item.id: item,
      };

  List<MediaItem> get _continueWatching {
    final byId = _byId;
    return _recentIds
        .map((id) => byId[id])
        .whereType<MediaItem>()
        .where((item) =>
            item.kind != MediaKind.live &&
            (_progress[item.id] ?? Duration.zero) > Duration.zero)
        .take(12)
        .toList();
  }

  List<MediaItem> get _recentlyWatched {
    final byId = _byId;
    return _recentIds
        .map((id) => byId[id])
        .whereType<MediaItem>()
        .take(12)
        .toList();
  }

  List<MediaItem> get _favorites {
    return widget.items
        .where((item) => _favoriteIds.contains(item.id))
        .take(12)
        .toList();
  }

  List<MediaItem> get _recentlyAdded {
    return widget.items
        .where((e) => e.kind != MediaKind.live)
        .take(14)
        .toList();
  }

  Future<void> _open(MediaItem item) async {
    final settings = await _prefs.load();
    if (settings.parentalEnabled && item.isAdult && mounted) {
      final ok = await _askPin();
      if (!ok || !mounted) return;
    }

    if (item.isSeriesCollection) {
      ZenqivoPlaylist? playlist;
      for (final value in widget.playlists) {
        if (value.id == item.playlistId) {
          playlist = value;
          break;
        }
      }
      if (playlist == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SeriesDetailsScreen(
            series: item,
            playlist: playlist!,
          ),
        ),
      );
    } else if (item.kind == MediaKind.movie) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: item)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
      );
    }
    await _load();
  }

  Future<bool> _askPin() async {
    final controller = TextEditingController();
    String? error;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(ZText.t('محتوى مقفول', 'Locked Content')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ZText.t(
                  'أدخل رمز الرقابة الأبوية للمتابعة.',
                  'Enter the parental PIN to continue.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(ZText.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await _prefs.verifyPin(controller.text);
                if (ok && context.mounted) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(
                    () => error = ZText.t(
                      'الرمز غير صحيح',
                      'Incorrect PIN',
                    ),
                  );
                }
              },
              child: Text(ZText.t('فتح', 'Unlock')),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final sections = <({String title, List<MediaItem> items, IconData icon})>[
      if (_continueWatching.isNotEmpty)
        (
          title: ZText.continueWatching,
          items: _continueWatching,
          icon: Icons.play_circle_outline_rounded,
        ),
      if (_recentlyWatched.isNotEmpty)
        (
          title: ZText.recentlyWatched,
          items: _recentlyWatched,
          icon: Icons.history_rounded,
        ),
      if (_favorites.isNotEmpty)
        (
          title: ZText.favorites,
          items: _favorites,
          icon: Icons.favorite_rounded,
        ),
      if (_recentlyAdded.isNotEmpty)
        (
          title: ZText.t(
            'المضاف حديثًا من المصدر',
            'Recently Added by Provider',
          ),
          items: _recentlyAdded,
          icon: Icons.auto_awesome_rounded,
        ),
    ];

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final section in sections) ...[
          const SizedBox(height: 28),
          _MediaRow(
            title: section.title,
            icon: section.icon,
            items: section.items,
            progress: _progress,
            onOpen: _open,
          ),
        ],
      ],
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.title,
    required this.icon,
    required this.items,
    required this.progress,
    required this.onOpen,
  });

  final String title;
  final IconData icon;
  final List<MediaItem> items;
  final Map<String, Duration> progress;
  final ValueChanged<MediaItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: ZenqivoColors.gold, size: 21),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 245,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _HomePoster(
                item: item,
                progress: progress[item.id],
                onTap: () => onOpen(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomePoster extends StatefulWidget {
  const _HomePoster({
    required this.item,
    required this.progress,
    required this.onTap,
  });

  final MediaItem item;
  final Duration? progress;
  final VoidCallback onTap;

  @override
  State<_HomePoster> createState() => _HomePosterState();
}

class _HomePosterState extends State<_HomePoster> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => focused = value),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: focused ? 1.035 : 1,
        child: SizedBox(
          width: 148,
          child: Material(
            color: ZenqivoColors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: focused
                        ? ZenqivoColors.gold
                        : const Color(0xFF282318),
                    width: focused ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: ZenqivoColors.surfaceRaised,
                            child: widget.item.logoUrl == null ||
                                    widget.item.logoUrl!.isEmpty
                                ? Icon(
                                    widget.item.kind == MediaKind.movie
                                        ? Icons.movie_rounded
                                        : widget.item.kind == MediaKind.live
                                            ? Icons.live_tv_rounded
                                            : Icons.video_library_rounded,
                                    color: ZenqivoColors.gold,
                                    size: 46,
                                  )
                                : Image.network(
                                    widget.item.logoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.play_circle_outline_rounded,
                                      color: ZenqivoColors.gold,
                                    ),
                                  ),
                          ),
                          if ((widget.progress ?? Duration.zero) > Duration.zero)
                            const Positioned(
                              left: 7,
                              bottom: 7,
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: ZenqivoColors.gold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        widget.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
