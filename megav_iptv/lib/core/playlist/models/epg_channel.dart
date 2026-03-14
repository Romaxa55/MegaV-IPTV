class EpgChannel {
  final String id;
  final String displayName;
  final String? icon;

  const EpgChannel({required this.id, required this.displayName, this.icon});

  Map<String, dynamic> toMap() => {'id': id, 'display_name': displayName, 'icon': icon};

  factory EpgChannel.fromMap(Map<String, dynamic> map) =>
      EpgChannel(id: map['id'] as String, displayName: map['display_name'] as String, icon: map['icon'] as String?);

  @override
  String toString() => 'EpgChannel(id: $id, name: $displayName)';
}
