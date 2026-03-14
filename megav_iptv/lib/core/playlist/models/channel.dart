class Channel {
  final int id;
  final String name;
  final String groupTitle;
  final String streamUrl;
  final int tvgRec;
  final String? logoUrl;
  final String? thumbnailUrl;
  final bool hasEpg;

  const Channel({
    required this.id,
    required this.name,
    this.groupTitle = '',
    this.streamUrl = '',
    this.tvgRec = 0,
    this.logoUrl,
    this.thumbnailUrl,
    this.hasEpg = false,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as int,
      name: json['name'] as String,
      groupTitle: json['groupTitle'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      tvgRec: json['tvgRec'] as int? ?? 0,
      logoUrl: json['logoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      hasEpg: json['hasEpg'] as bool? ?? false,
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
