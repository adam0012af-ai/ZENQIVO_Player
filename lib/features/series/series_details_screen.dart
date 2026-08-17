import 'package:flutter/material.dart';

import '../../core/localization/zenqivo_strings.dart';

import '../../core/models/media_item.dart';
import '../../core/models/playlist.dart';
import '../../core/models/series_episode.dart';
import '../../core/services/player_preferences_service.dart';
import '../../core/services/xtream_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import '../player/player_screen.dart';

class SeriesDetailsScreen extends StatefulWidget {
  const SeriesDetailsScreen({
    super.key,
    required this.series,
    required this.playlist,
  });

  final MediaItem series;
  final ZenqivoPlaylist playlist;

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  final _service = XtreamService();
  final _prefs = PlayerPreferencesService();

  late final Future<List<SeriesEpisode>> _future = _load();
  int? _selectedSeason;
  Set<String> _favorites = {};
  Map<String, Duration> _progress = const {};

  Future<List<SeriesEpisode>> _load() async {
    final id = widget.series.seriesId;
    if (id == null) return const [];
    final episodes = await _service.loadSeriesEpisodes(widget.playlist, id);
    final favorites = await _prefs.favorites();
    final progress = await _prefs.allProgress();
    if (mounted) {
      setState(() {
        _favorites = favorites;
        _progress = progress;
      });
    }
    return episodes;
  }

  Future<void> _toggleFavorite() async {
    await _prefs.toggleFavorite(widget.series.id);
    final values = await _prefs.favorites();
    if (mounted) setState(() => _favorites = values);
  }

  Future<void> _openEpisode(SeriesEpisode episode) async {
    final item = MediaItem(
      id: 'xt-episode-${episode.id}',
      title: episode.title,
      streamUrl: episode.streamUrl,
      kind: MediaKind.series,
      playlistId: widget.playlist.id,
      logoUrl: widget.series.logoUrl,
      group: widget.series.group,
      containerExtension: episode.containerExtension,
      description: widget.series.description,
      isAdult: widget.series.isAdult,
      year: widget.series.year,
      rating: widget.series.rating,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
    );
    final progress = await _prefs.allProgress();
    if (mounted) setState(() => _progress = progress);
  }

  String _duration(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${value.inMinutes}:$s';
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<SeriesEpisode>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: ZenqivoColors.gold),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  ZText.t('تعذر تحميل المواسم والحلقات.', 'Unable to load seasons and episodes.'),
                  style: TextStyle(color: ZenqivoColors.muted),
                ),
              );
            }

            final episodes = snapshot.data ?? const [];
            if (episodes.isEmpty) {
              return const Center(
                child: Text(
                  ZText.t('لا توجد حلقات متاحة.', 'No episodes available.'),
                  style: TextStyle(color: ZenqivoColors.muted),
                ),
              );
            }

            final seasons = episodes.map((e) => e.season).toSet().toList()..sort();
            _selectedSeason ??= seasons.first;
            final visible = episodes
                .where((e) => e.season == _selectedSeason)
                .toList();

            return Column(
              children: [
                _SeriesHero(
                  series: series,
                  episodeCount: episodes.length,
                  seasonCount: seasons.length,
                  favorite: _favorites.contains(series.id),
                  onBack: () => Navigator.maybePop(context),
                  onFavorite: _toggleFavorite,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final season in seasons) ...[
                                ChoiceChip(
                                  label: Text(ZText.t('الموسم $season', 'Season $season')),
                                  selected: _selectedSeason == season,
                                  selectedColor: const Color(0xFF3A3113),
                                  side: BorderSide(
                                    color: _selectedSeason == season
                                        ? ZenqivoColors.gold
                                        : const Color(0xFF2A2618),
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _selectedSeason = season),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 1300
                                  ? 5
                                  : constraints.maxWidth >= 980
                                      ? 4
                                      : constraints.maxWidth >= 680
                                          ? 3
                                          : 2;
                              return GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.75,
                                ),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final episode = visible[index];
                                  final key = 'xt-episode-${episode.id}';
                                  return _EpisodeCard(
                                    episode: episode,
                                    progress: _progress[key],
                                    onTap: () => _openEpisode(episode),
                                    durationLabel: _duration,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SeriesHero extends StatelessWidget {
  const _SeriesHero({
    required this.series,
    required this.episodeCount,
    required this.seasonCount,
    required this.favorite,
    required this.onBack,
    required this.onFavorite,
  });

  final MediaItem series;
  final int episodeCount;
  final int seasonCount;
  final bool favorite;
  final VoidCallback onBack;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF090909), Color(0xFF251F0D)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: ZenqivoColors.surfaceRaised,
                  child: series.logoUrl == null || series.logoUrl!.isEmpty
                      ? const Icon(
                          Icons.video_library_rounded,
                          size: 70,
                          color: ZenqivoColors.gold,
                        )
                      : Image.network(
                          series.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.video_library_rounded,
                            size: 70,
                            color: ZenqivoColors.gold,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _HeroChip(text: ZText.t('$seasonCount مواسم', '$seasonCount Seasons')),
                    _HeroChip(text: ZText.t('$episodeCount حلقات', '$episodeCount Episodes')),
                    if (series.year != null) _HeroChip(text: series.year!),
                    if (series.rating != null)
                      _HeroChip(text: '★ ${series.rating}'),
                    if (series.group != null) _HeroChip(text: series.group!),
                  ],
                ),
                const SizedBox(height: 16),
                if (series.description != null &&
                    series.description!.trim().isNotEmpty)
                  Text(
                    series.description!,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZenqivoColors.muted,
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: onFavorite,
                  icon: Icon(
                    favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                  label: Text(
                    favorite ? ZText.t('إزالة من المفضلة', 'Remove from Favorites') : ZText.t('إضافة للمفضلة', 'Add to Favorites'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xAA111111),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF4A3D16)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: ZenqivoColors.goldSoft,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  const _EpisodeCard({
    required this.episode,
    required this.progress,
    required this.onTap,
    required this.durationLabel,
  });

  final SeriesEpisode episode;
  final Duration? progress;
  final VoidCallback onTap;
  final String Function(Duration value) durationLabel;

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: ZenqivoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focused ? ZenqivoColors.gold : const Color(0xFF262117),
            width: _focused ? 2 : 1,
          ),
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: Color(0x44D4AF37),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2712),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${episode.episodeNumber}',
                      style: const TextStyle(
                        color: ZenqivoColors.goldSoft,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.progress != null &&
                                  widget.progress! > Duration.zero
                              ? ZText.t('متابعة من ${widget.durationLabel(widget.progress!)}', 'Resume from ${widget.durationLabel(widget.progress!)}')
                              : ZText.t('الموسم ${episode.season} · الحلقة ${episode.episodeNumber}', 'Season ${episode.season} · Episode ${episode.episodeNumber}'),
                          style: const TextStyle(
                            color: ZenqivoColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: ZenqivoColors.gold,
                    size: 34,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
