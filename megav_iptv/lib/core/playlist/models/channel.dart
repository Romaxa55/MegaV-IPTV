class Channel {
  final String id;
  final String name;
  final String? logoUrl;
  final String? country;
  final List<String> categories;
  final bool isNsfw;
  final int streamCount;
  final int workingCount;
  final bool hasEpg;
  final String? thumbnailUrl;

  const Channel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.country,
    this.categories = const [],
    this.isNsfw = false,
    this.streamCount = 0,
    this.workingCount = 0,
    this.hasEpg = false,
    this.thumbnailUrl,
  });

  String? get groupTitle => categories.isNotEmpty ? categories.first : null;

  factory Channel.fromJson(Map<String, dynamic> json) {
    final cats = json['categories'];
    return Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String?,
      country: json['country'] as String?,
      categories: cats is List ? cats.cast<String>() : const [],
      isNsfw: json['isNsfw'] as bool? ?? false,
      streamCount: json['streamCount'] as int? ?? 0,
      workingCount: json['workingCount'] as int? ?? 0,
      hasEpg: json['hasEpg'] as bool? ?? false,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  @override
  String toString() => 'Channel(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Channel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
