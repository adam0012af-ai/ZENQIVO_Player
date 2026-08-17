class SeriesEpisode {
  const SeriesEpisode({
    required this.id,
    required this.title,
    required this.episodeNumber,
    required this.season,
    required this.streamUrl,
    this.containerExtension,
    this.info,
  });

  final String id;
  final String title;
  final int episodeNumber;
  final int season;
  final String streamUrl;
  final String? containerExtension;
  final Map<String, dynamic>? info;
}
