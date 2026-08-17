enum MediaKind { live, movie, series }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.kind,
    required this.playlistId,
    this.logoUrl,
    this.group,
    this.tvgId,
    this.isAdult = false,
    this.seriesId,
    this.categoryId,
    this.containerExtension,
    this.description,
    this.year,
    this.rating,
  });

  final String id;
  final String title;
  final String streamUrl;
  final MediaKind kind;
  final int playlistId;
  final String? logoUrl;
  final String? group;
  final String? tvgId;
  final bool isAdult;

  final int? seriesId;
  final String? categoryId;
  final String? containerExtension;
  final String? description;
  final String? year;
  final String? rating;

  bool get isSeriesCollection => kind == MediaKind.series && seriesId != null && streamUrl.isEmpty;
}
