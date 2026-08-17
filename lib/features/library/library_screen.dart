import 'package:flutter/material.dart';

import '../../core/localization/zenqivo_strings.dart';

import '../../core/models/epg_program.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playlist.dart';
import '../../core/services/player_preferences_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import '../movie/movie_details_screen.dart';
import '../player/player_screen.dart';
import '../search/search_screen.dart';
import '../series/series_details_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.epg,
    required this.playlists,
    this.kind,
    this.favoritesOnly = false,
  });

  final String title;
  final IconData icon;
  final List<MediaItem> items;
  final Map<String, List<EpgProgram>> epg;
  final List<ZenqivoPlaylist> playlists;
  final MediaKind? kind;
  final bool favoritesOnly;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _prefs = PlayerPreferencesService();
  Set<String> _favorites = {};
  String _query = '';
  String? _group;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final values = await _prefs.favorites();
    if (mounted) setState(() => _favorites = values);
  }

  List<MediaItem> get _visible {
    Iterable<MediaItem> values = widget.items;
    if (widget.kind != null) values = values.where((e) => e.kind == widget.kind);
    if (widget.favoritesOnly) values = values.where((e) => _favorites.contains(e.id));
    if (_group != null) values = values.where((e) => e.group == _group);
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      values = values.where((e) => e.title.toLowerCase().contains(q));
    }
    return values.toList();
  }

  List<String> get _groups {
    Iterable<MediaItem> values = widget.items;
    if (widget.kind != null) values = values.where((e) => e.kind == widget.kind);
    final groups = values.map((e) => e.group).whereType<String>().where((e) => e.isNotEmpty).toSet().toList();
    groups.sort();
    return groups;
  }

  EpgProgram? _now(MediaItem item) {
    final id = item.tvgId;
    if (id == null) return null;
    for (final p in widget.epg[id] ?? const <EpgProgram>[]) {
      if (p.isNow) return p;
    }
    return null;
  }

  EpgProgram? _next(MediaItem item) {
    final id = item.tvgId;
    if (id == null) return null;
    final now = DateTime.now();
    for (final p in widget.epg[id] ?? const <EpgProgram>[]) {
      if (p.start.isAfter(now)) return p;
    }
    return null;
  }

  Future<void> _open(MediaItem item) async {
    final settings = await _prefs.load();
    if (settings.parentalEnabled && item.isAdult && mounted) {
      final ok = await _askPin(context, _prefs);
      if (!ok || !mounted) return;
    }
    if (!mounted) return;

    if (item.isSeriesCollection) {
      final playlist = widget.playlists.where((p) => p.id == item.playlistId).firstOrNull;
      if (playlist == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SeriesDetailsScreen(series: item, playlist: playlist),
        ),
      );
      return;
    }

    if (item.kind == MediaKind.movie) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MovieDetailsScreen(movie: item),
        ),
      );
      await _loadFavorites();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
    );
  }

  Future<void> _favorite(MediaItem item) async {
    await _prefs.toggleFavorite(item.id);
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(widget.icon, color: ZenqivoColors.gold, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
            SizedBox(
              width: 260,
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: ZText.t('بحث داخل القسم', 'Search this section'),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (_groups.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: Text(ZText.t('الكل', 'All')),
                    selected: _group == null,
                    onSelected: (_) => setState(() => _group = null),
                  ),
                  const SizedBox(width: 8),
                  for (final group in _groups) ...[
                    ChoiceChip(
                      label: Text(group),
                      selected: _group == group,
                      onSelected: (_) => setState(() => _group = group),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      widget.favoritesOnly ? ZText.t('لا توجد عناصر في المفضلة.', 'No items in favorites.') : ZText.t('لا يوجد محتوى مطابق.', 'No matching content.'),
                      style: const TextStyle(color: ZenqivoColors.muted),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final columns = width >= 1500
                          ? 7
                          : width >= 1200
                              ? 6
                              : width >= 950
                                  ? 5
                                  : width >= 700
                                      ? 4
                                      : width >= 480
                                          ? 3
                                          : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: .60,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final item = visible[i];
                          return _PosterCard(
                            item: item,
                            favorite: _favorites.contains(item.id),
                            onTap: () => _open(item),
                            onFavorite: () => _favorite(item),
                          );
                        },
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}


Future<bool> _askPin(
  BuildContext context,
  PlayerPreferencesService prefs,
) async {
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
              Text(
                error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ZText.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await prefs.verifyPin(controller.text);
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

class _PosterCard extends StatefulWidget {
  const _PosterCard({
    required this.item,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });

  final MediaItem item;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  State<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<_PosterCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        transform: Matrix4.diagonal3Values(
          _focused ? 1.025 : 1.0,
          _focused ? 1.025 : 1.0,
          1.0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _focused ? ZenqivoColors.gold : const Color(0xFF242015),
            width: _focused ? 2 : 1,
          ),
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: Color(0x44D4AF37),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: ZenqivoColors.surface,
          borderRadius: BorderRadius.circular(17),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: ZenqivoColors.surfaceRaised,
                        child: item.logoUrl == null || item.logoUrl!.isEmpty
                            ? Icon(
                                item.kind == MediaKind.movie
                                    ? Icons.movie_rounded
                                    : Icons.video_library_rounded,
                                size: 54,
                                color: ZenqivoColors.gold,
                              )
                            : Image.network(
                                item.logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  item.kind == MediaKind.movie
                                      ? Icons.movie_rounded
                                      : Icons.video_library_rounded,
                                  size: 54,
                                  color: ZenqivoColors.gold,
                                ),
                              ),
                      ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Material(
                          color: const Color(0xB0000000),
                          shape: const CircleBorder(),
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: widget.onFavorite,
                            icon: Icon(
                              widget.favorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: widget.favorite
                                  ? ZenqivoColors.gold
                                  : Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      if (item.rating != null)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xD0000000),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: ZenqivoColors.gold,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.rating!,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.year ?? item.group ?? _kindLabel(item.kind),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ZenqivoColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (item.isAdult)
                            const Icon(
                              Icons.lock_rounded,
                              size: 15,
                              color: ZenqivoColors.gold,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(MediaKind kind) => switch (kind) {
        MediaKind.live => ZText.live,
        MediaKind.movie => ZText.t('فيلم', 'Movie'),
        MediaKind.series => ZText.t('مسلسل', 'Series'),
      };
}

class _Logo extends StatelessWidget {
  const _Logo({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.logoUrl;
    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ZenqivoColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: url == null || url.isEmpty
          ? Icon(
              item.kind == MediaKind.live
                  ? Icons.live_tv_rounded
                  : item.kind == MediaKind.movie
                      ? Icons.movie_rounded
                      : Icons.video_library_rounded,
              color: ZenqivoColors.gold,
            )
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_outline_rounded, color: ZenqivoColors.gold),
            ),
    );
  }
}


extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
