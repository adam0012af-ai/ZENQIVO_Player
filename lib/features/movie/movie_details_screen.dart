import 'package:flutter/material.dart';

import '../../core/localization/zenqivo_strings.dart';

import '../../core/models/media_item.dart';
import '../../core/services/player_preferences_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import '../player/player_screen.dart';

class MovieDetailsScreen extends StatefulWidget {
  const MovieDetailsScreen({
    super.key,
    required this.movie,
  });

  final MediaItem movie;

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final _prefs = PlayerPreferencesService();
  bool _favorite = false;
  Duration? _resumeAt;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final favorites = await _prefs.favorites();
    final progress = await _prefs.loadProgress(widget.movie.id);
    if (!mounted) return;
    setState(() {
      _favorite = favorites.contains(widget.movie.id);
      _resumeAt = progress;
    });
  }

  Future<void> _toggleFavorite() async {
    await _prefs.toggleFavorite(widget.movie.id);
    await _loadState();
  }

  Future<void> _play() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(item: widget.movie),
      ),
    );
    await _loadState();
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (movie.logoUrl != null && movie.logoUrl!.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: .10,
                  child: Image.network(
                    movie.logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      ZenqivoColors.background,
                      ZenqivoColors.background.withValues(alpha: .94),
                      ZenqivoColors.background.withValues(alpha: .76),
                    ],
                  ),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.all(28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ZText.t('تفاصيل الفيلم', 'Movie Details'),
                      style: TextStyle(
                        color: ZenqivoColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MoviePoster(movie: movie, width: 300),
                      const SizedBox(width: 34),
                      Expanded(
                        child: _MovieInfo(
                          movie: movie,
                          resumeAt: _resumeAt,
                          favorite: _favorite,
                          onPlay: _play,
                          onFavorite: _toggleFavorite,
                          formatDuration: _format,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _MoviePoster(movie: movie, width: 220)),
                      const SizedBox(height: 24),
                      _MovieInfo(
                        movie: movie,
                        resumeAt: _resumeAt,
                        favorite: _favorite,
                        onPlay: _play,
                        onFavorite: _toggleFavorite,
                        formatDuration: _format,
                      ),
                    ],
                  ),              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _MoviePoster extends StatelessWidget {
  const _MoviePoster({
    required this.movie,
    required this.width,
  });

  final MediaItem movie;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            color: ZenqivoColors.surfaceRaised,
            child: movie.logoUrl == null || movie.logoUrl!.isEmpty
                ? const Icon(
                    Icons.movie_rounded,
                    size: 88,
                    color: ZenqivoColors.gold,
                  )
                : Image.network(
                    movie.logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.movie_rounded,
                      size: 88,
                      color: ZenqivoColors.gold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MovieInfo extends StatelessWidget {
  const _MovieInfo({
    required this.movie,
    required this.resumeAt,
    required this.favorite,
    required this.onPlay,
    required this.onFavorite,
    required this.formatDuration,
  });

  final MediaItem movie;
  final Duration? resumeAt;
  final bool favorite;
  final VoidCallback onPlay;
  final VoidCallback onFavorite;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movie.title,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (movie.year != null)
                _MetaChip(
                  icon: Icons.calendar_today_rounded,
                  text: movie.year!,
                ),
              if (movie.rating != null)
                _MetaChip(
                  icon: Icons.star_rounded,
                  text: movie.rating!,
                ),
              if (movie.group != null)
                _MetaChip(
                  icon: Icons.category_rounded,
                  text: movie.group!,
                ),
              if (movie.containerExtension != null)
                _MetaChip(
                  icon: Icons.high_quality_rounded,
                  text: movie.containerExtension!.toUpperCase(),
                ),
              if (movie.isAdult)
                _MetaChip(
                  icon: Icons.lock_rounded,
                  text: ZText.t('مقيد', 'Restricted'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            movie.description?.trim().isNotEmpty == true
                ? movie.description!
                : ZText.t('لا يتوفر وصف لهذا الفيلم من المصدر.', 'No description is available from the provider.'),
            style: const TextStyle(
              color: ZenqivoColors.muted,
              fontSize: 16,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  backgroundColor: ZenqivoColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  resumeAt != null && resumeAt! > Duration.zero
                      ? ZText.t('متابعة من ${formatDuration(resumeAt!)}', 'Resume from ${formatDuration(resumeAt!)}')
                      : ZText.t('تشغيل الآن', 'Play Now'),
                ),
              ),
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
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ZenqivoColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF3A321A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ZenqivoColors.gold),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}
