class Channel {
  final String id;
  final String name;
  final String url;
  final String? logoUrl;
  final String? groupTitle;
  final String? thumbnailUrl;

  const Channel({
    required this.id,
    required this.name,
    required this.url,
    this.logoUrl,
    this.groupTitle,
    this.thumbnailUrl,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      logoUrl: json['logoUrl'] as String?,
      groupTitle: json['groupTitle'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  @override
  String toString() => 'Channel(id: $id, name: $name, group: $groupTitle)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Channel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
