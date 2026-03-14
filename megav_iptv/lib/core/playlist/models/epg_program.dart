class EpgProgram {
  final String id;
  final String channelId;
  final String title;
  final String? description;
  final String? category;
  final String? icon;
  final String? lang;
  final DateTime start;
  final DateTime end;

  const EpgProgram({
    required this.id,
    required this.channelId,
    required this.title,
    this.description,
    this.category,
    this.icon,
    this.lang,
    required this.start,
    required this.end,
  });

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  Duration get duration => end.difference(start);

  double get progress {
    final now = DateTime.now();
    if (now.isBefore(start)) return 0;
    if (now.isAfter(end)) return 1;
    return now.difference(start).inSeconds / duration.inSeconds;
  }

  Duration get remaining {
    final now = DateTime.now();
    if (now.isAfter(end)) return Duration.zero;
    return end.difference(now);
  }

  Duration get elapsed {
    final now = DateTime.now();
    if (now.isBefore(start)) return Duration.zero;
    return now.difference(start);
  }

  factory EpgProgram.fromJson(Map<String, dynamic> json) {
    return EpgProgram(
      id: (json['id'] ?? '').toString(),
      channelId: json['channelId'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      icon: json['icon'] as String?,
      lang: json['lang'] as String?,
      start: DateTime.parse(json['start'] as String).toLocal(),
      end: DateTime.parse(json['end'] as String).toLocal(),
    );
  }

  @override
  String toString() => 'EpgProgram(title: $title, ${isNow ? "NOW" : ""})';
}
