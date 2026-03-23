class EpgProgram {
  final int id;
  final int channelId;
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
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      channelId: json['channelId'] is int ? json['channelId'] as int : int.tryParse(json['channelId'].toString()) ?? 0,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      icon: json['icon'] as String?,
      lang: json['lang'] as String?,
      start: DateTime.parse(json['start'] as String).toLocal(),
      end: DateTime.parse(json['end'] as String).toLocal(),
    );
  }

  /// Parses year from the first line of description (e.g. "1981 г." → "1981")
  String? get parsedYear {
    if (description == null) return null;
    final match = RegExp(r'(\d{4})\s*г?\.?').firstMatch(description!.split('\n').first);
    return match?.group(1);
  }

  /// Returns the actual synopsis (everything after the first blank line in description).
  /// Strips the leading year line (e.g. "1981 г.") so it's not duplicated.
  String? get synopsis {
    if (description == null) return null;
    final idx = description!.indexOf('\n\n');
    if (idx >= 0) {
      final text = description!.substring(idx + 2).trim();
      return text.isEmpty ? null : text;
    }
    // No double-newline — check if the whole description is just a year
    if (RegExp(r'^\d{4}\s*г?\.?\s*$').hasMatch(description!.trim())) return null;
    return description;
  }

  @override
  String toString() => 'EpgProgram(title: $title, ${isNow ? "NOW" : ""})';
}
