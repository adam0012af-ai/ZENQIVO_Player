import 'package:flutter/material.dart';

import '../../core/localization/zenqivo_strings.dart';
import '../../core/models/epg_program.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playlist.dart';
import '../../core/models/profile.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/playlist_catalog_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import 'home_discovery_rows.dart';
import '../history/history_screen.dart';
import '../library/library_screen.dart';
import '../live/live_tv_screen.dart';
import '../profile/profile_selection_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.identity,
    required this.playlists,
    required this.syncedAt,
    required this.profile,
  });

  final DeviceIdentity identity;
  final List<ZenqivoPlaylist> playlists;
  final DateTime syncedAt;
  final ZenqivoProfile profile;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _catalogService = PlaylistCatalogService();
  final _epgService = EpgService();

  int index = 0;
  bool loading = true;
  String? error;
  String? warning;
  List<MediaItem> items = const [];
  Map<String, List<EpgProgram>> epg = const {};

  List<(IconData, String)> get destinations => [
    (Icons.home_rounded, ZText.home),
    (Icons.live_tv_rounded, ZText.live),
    (Icons.movie_rounded, ZText.movies),
    (Icons.video_library_rounded, ZText.series),
    (Icons.favorite_rounded, ZText.favorites),
    (Icons.history_rounded, ZText.watching),
    (Icons.settings_rounded, ZText.settings),
  ];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog({bool forceRefresh = false}) async {
    setState(() {
      loading = true;
      error = null;
      warning = null;
    });

    try {
      final catalog = await _catalogService.load(
        widget.playlists,
        forceRefresh: forceRefresh,
      );

      final guide = await _epgService.load(
        catalog.epgUrls,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      final failedCount =
          catalog.failedSources.length + guide.failedUrls.length;

      setState(() {
        if (catalog.items.isNotEmpty || items.isEmpty) {
          items = catalog.items;
        }
        if (guide.programs.isNotEmpty || epg.isEmpty) {
          epg = guide.programs;
        }

        loading = false;

        if (failedCount > 0) {
          warning = ZText.t(
            'بعض المصادر غير متاحة حاليًا. تم عرض البيانات المتوفرة${catalog.usedStaleCache || guide.usedStaleCache ? ' مع استخدام آخر نسخة محفوظة لبعض المصادر.' : '.'}',
            'Some sources are currently unavailable. Available data is shown${catalog.usedStaleCache || guide.usedStaleCache ? ' with cached data used for some sources.' : '.'}',
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = ZText.t(
          'تعذر تحديث المكتبة. سيتم الاحتفاظ بالبيانات الحالية.',
          'Unable to refresh the library. Current data will be kept.',
        );
      });
    }
  }

  List<Widget> get pages => [
        _Dashboard(
          playlists: widget.playlists,
          syncedAt: widget.syncedAt,
          items: items,
          epg: epg,
          loading: loading,
          error: error,
          warning: warning,
          onSearch: _openSearch,
          onReload: () => _loadCatalog(forceRefresh: true),
          onOpenSection: (value) => setState(() => index = value),
          profile: widget.profile,
          onSwitchProfile: _switchProfile,
        ),
        LiveTvScreen(
          key: const ValueKey('live-tv'),
          items: items,
          epg: epg,
        ),
        LibraryScreen(
          key: const ValueKey('movies'),
          title: ZText.movies,
          icon: Icons.movie_rounded,
          kind: MediaKind.movie,
          items: items,
          epg: epg,
          playlists: widget.playlists,
        ),
        LibraryScreen(
          key: const ValueKey('series'),
          title: ZText.series,
          icon: Icons.video_library_rounded,
          kind: MediaKind.series,
          items: items,
          epg: epg,
          playlists: widget.playlists,
        ),
        LibraryScreen(
          key: const ValueKey('favorites'),
          title: ZText.favorites,
          icon: Icons.favorite_rounded,
          items: items,
          epg: epg,
          playlists: widget.playlists,
          favoritesOnly: true,
        ),
        HistoryScreen(
          key: const ValueKey('history'),
          items: items,
        ),
        SettingsScreen(
          identity: widget.identity,
          profile: widget.profile,
          onSwitchProfile: _switchProfile,
        ),
      ];

  void _switchProfile() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProfileSelectionScreen(
          identity: widget.identity,
          playlists: widget.playlists,
          syncedAt: widget.syncedAt,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchScreen(items: items, epg: epg, playlists: widget.playlists)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            labelType: NavigationRailLabelType.all,
            backgroundColor: ZenqivoColors.surface,
            indicatorColor: const Color(0xFF3A3214),
            selectedIconTheme: const IconThemeData(color: ZenqivoColors.gold),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
            ],
          ),
          Expanded(child: pages[index]),
        ]),
      );
    }

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.$1), label: d.$2),
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.playlists,
    required this.syncedAt,
    required this.items,
    required this.epg,
    required this.loading,
    required this.error,
    required this.warning,
    required this.onSearch,
    required this.onReload,
    required this.onOpenSection,
    required this.profile,
    required this.onSwitchProfile,
  });

  final List<ZenqivoPlaylist> playlists;
  final DateTime syncedAt;
  final List<MediaItem> items;
  final Map<String, List<EpgProgram>> epg;
  final bool loading;
  final String? error;
  final String? warning;
  final VoidCallback onSearch;
  final VoidCallback onReload;
  final ValueChanged<int> onOpenSection;
  final ZenqivoProfile profile;
  final VoidCallback onSwitchProfile;

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  int get live => items.where((e) => e.kind == MediaKind.live).length;
  int get movies => items.where((e) => e.kind == MediaKind.movie).length;
  int get series => items.where((e) => e.kind == MediaKind.series).length;
  int get guideChannels => epg.keys.length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ZENQIVO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4)),
                Text('PLAYER', style: TextStyle(color: ZenqivoColors.gold, fontSize: 11, letterSpacing: 5)),
              ]),
            ),
            TextButton.icon(
              onPressed: onSwitchProfile,
              icon: const Icon(Icons.account_circle_rounded, color: ZenqivoColors.gold),
              label: Text(profile.name),
            ),
            IconButton(onPressed: onSearch, icon: const Icon(Icons.search_rounded)),
            IconButton(onPressed: onReload, icon: const Icon(Icons.refresh_rounded)),
          ]),
          const SizedBox(height: 14),
          Text(
            ZText.t('القوائم المتصلة: ${playlists.length} · آخر مزامنة ${_time(syncedAt)}', 'Connected playlists: ${playlists.length} · Last sync ${_time(syncedAt)}'),
            style: const TextStyle(color: ZenqivoColors.muted),
          ),
          const SizedBox(height: 18),
          Container(
            height: 230,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF2C2410), Color(0xFF0B0B0B)]),
              border: Border.all(color: const Color(0xFF473B18)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ZENQIVO PREMIUM PLAYER', style: TextStyle(color: ZenqivoColors.goldSoft, fontSize: 13, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(
                  loading ? ZText.t('جاري مزامنة مكتبتك...', 'Syncing your library...') : ZText.t('${items.length} عنصر جاهز للمشاهدة', '${items.length} items ready to watch'),
                  style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  error ?? warning ?? 'Live TV • Movies • Series • XMLTV EPG',
                  style: TextStyle(
                    color: error != null
                        ? ZenqivoColors.danger
                        : warning != null
                            ? ZenqivoColors.goldSoft
                            : ZenqivoColors.muted,
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(color: ZenqivoColors.gold),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FeatureCard(icon: Icons.live_tv_rounded, title: ZText.t('البث المباشر', 'Live TV'), value: '$live', onTap: () => onOpenSection(1)),
              _FeatureCard(icon: Icons.movie_rounded, title: ZText.movies, value: '$movies', onTap: () => onOpenSection(2)),
              _FeatureCard(icon: Icons.video_library_rounded, title: ZText.series, value: '$series', onTap: () => onOpenSection(3)),
              _FeatureCard(icon: Icons.calendar_month_rounded, title: ZText.t('قنوات EPG', 'EPG Channels'), value: '$guideChannels', onTap: () => onOpenSection(1)),
              _FeatureCard(icon: Icons.favorite_rounded, title: ZText.favorites, value: ZText.t('محلي', 'Local'), onTap: () => onOpenSection(4)),
              _FeatureCard(icon: Icons.search_rounded, title: ZText.t('بحث شامل', 'Global Search'), value: ZText.search, onTap: onSearch),
            ],
          ),
          HomeDiscoveryRows(
            items: items,
            playlists: playlists,
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 185,
      height: 118,
      child: Material(
        color: ZenqivoColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF242015)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(icon, color: ZenqivoColors.gold),
                  const Spacer(),
                  Text(value, style: const TextStyle(color: ZenqivoColors.goldSoft, fontWeight: FontWeight.w800)),
                ]),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
