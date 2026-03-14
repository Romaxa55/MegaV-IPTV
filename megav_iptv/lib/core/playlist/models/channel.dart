class Channel {
  final String name;
  final String url;
  final String? logoUrl;
  final String? groupTitle;
  final String? tvgId;
  final String? tvgName;
  final String? language;

  const Channel({
    required this.name,
    required this.url,
    this.logoUrl,
    this.groupTitle,
    this.tvgId,
    this.tvgName,
    this.language,
  });

  @override
  String toString() => 'Channel(name: $name, group: $groupTitle)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          url == other.url;

  @override
  int get hashCode => name.hashCode ^ url.hashCode;
}
