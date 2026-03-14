class EpgProgram {
  final String channelId;
  final String title;
  final String? description;
  final String? category;
  final String? icon;
  final DateTime start;
  final DateTime end;

  const EpgProgram({
    required this.channelId,
    required this.title,
    this.description,
    this.category,
    this.icon,
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

  Map<String, dynamic> toMap() => {
    'channel_id': channelId,
    'title': title,
    'description': description,
    'category': category,
    'icon': icon,
    'start': start.millisecondsSinceEpoch,
    'end_time': end.millisecondsSinceEpoch,
  };

  factory EpgProgram.fromMap(Map<String, dynamic> map) => EpgProgram(
    channelId: map['channel_id'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    category: map['category'] as String?,
    icon: map['icon'] as String?,
    start: DateTime.fromMillisecondsSinceEpoch(map['start'] as int),
    end: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
  );

  @override
  String toString() => 'EpgProgram(channel: $channelId, title: $title, ${isNow ? "NOW" : ""})';
}
