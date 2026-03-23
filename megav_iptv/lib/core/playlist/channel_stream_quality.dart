import 'models/channel.dart';

/// Качество потока по названию канала / группы (M3U часто кладёт HD/UHD в имя).
enum ChannelStreamQuality {
  uhd,
  hd,
  sd;

  String get label => switch (this) {
    ChannelStreamQuality.uhd => 'UHD',
    ChannelStreamQuality.hd => 'HD',
    ChannelStreamQuality.sd => 'SD',
  };
}

/// Определяет метку качества по строкам из плейлиста.
/// Возвращает `null`, если явных маркеров нет — не показываем «SD» всем подряд.
ChannelStreamQuality? detectChannelStreamQuality(String name, {String? groupTitle}) {
  final haystack = _normalizeForMatch('$name ${groupTitle ?? ''}');

  if (_matchesUhd(haystack)) return ChannelStreamQuality.uhd;
  if (_matchesHd(haystack)) return ChannelStreamQuality.hd;
  if (_matchesSd(haystack)) return ChannelStreamQuality.sd;
  return null;
}

extension ChannelStreamQualityX on Channel {
  ChannelStreamQuality? get streamQuality => detectChannelStreamQuality(name, groupTitle: groupTitle);
}

String _normalizeForMatch(String s) {
  var t = s.toLowerCase().trim();
  t = t.replaceAll('ё', 'е');
  return t;
}

bool _matchesUhd(String s) {
  final patterns = <RegExp>[
    RegExp(r'\b4k\b'),
    RegExp(r'\b4\s*k\b'),
    RegExp(r'4к'),
    RegExp(r'4\s*к'),
    RegExp(r'\buhd\b'),
    RegExp(r'ultra\s*hd'),
    RegExp(r'\b2160\b'),
    RegExp(r'2160p'),
    RegExp(r'\b3840\b'),
    RegExp(r'\b4320\b'),
    RegExp(r'\b8k\b'),
    RegExp(r'\b8\s*k\b'),
    RegExp(r'ультра\s*hd'),
    RegExp(r'ультрахд'),
    RegExp(r'\bhdr10\b'),
    RegExp(r'\bdolby\s*vision\b'),
  ];
  return patterns.any((r) => r.hasMatch(s));
}

bool _matchesHd(String s) {
  final patterns = <RegExp>[
    RegExp(r'\bhd\b'),
    RegExp(r'\bfhd\b'),
    RegExp(r'full\s*hd'),
    RegExp(r'\bhdtv\b'),
    RegExp(r'\b720p\b'),
    RegExp(r'\b720i\b'),
    RegExp(r'\b720\b'),
    RegExp(r'\b1080p\b'),
    RegExp(r'\b1080i\b'),
    RegExp(r'\b1080\b'),
    RegExp(r'\b2k\b'),
    RegExp(r'high\s*def'),
    RegExp(r'высок(ая|ое)\s*четкост'),
    RegExp(r'высокой\s*четкости'),
  ];
  return patterns.any((r) => r.hasMatch(s));
}

bool _matchesSd(String s) {
  final patterns = <RegExp>[
    RegExp(r'\bsd\b'),
    RegExp(r'\blq\b'),
    RegExp(r'low\s*qual'),
    RegExp(r'\b480p\b'),
    RegExp(r'\b480i\b'),
    RegExp(r'\b480\b'),
    RegExp(r'\b576p\b'),
    RegExp(r'\b576i\b'),
    RegExp(r'\b576\b'),
    RegExp(r'standard\s*def'),
    RegExp(r'стандартн(ая|ое)\s*четкост'),
  ];
  return patterns.any((r) => r.hasMatch(s));
}
