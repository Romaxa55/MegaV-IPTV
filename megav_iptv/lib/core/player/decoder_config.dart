import 'dart:io' show Platform;

enum DecoderMode {
  auto('Auto', 'auto', false),
  system('System', '', true),
  hardware('Hardware', 'mediacodec', false),
  hardwarePlus('HW+', 'mediacodec-copy', false),
  software('Software', 'no', false);

  const DecoderMode(this.label, this.hwdecValue, this.usesMedia3);

  final String label;
  final String hwdecValue;
  final bool usesMedia3;

  String get description => switch (this) {
    DecoderMode.auto => 'media_kit HW -> SW fallback',
    DecoderMode.system => 'Media3 native (AFR, HDR)',
    DecoderMode.hardware => 'libmpv hwdec=mediacodec',
    DecoderMode.hardwarePlus => 'libmpv hwdec=mediacodec-copy',
    DecoderMode.software => 'libmpv hwdec=no (FFmpeg)',
  };
}

enum BufferMode {
  minimal('Minimal', 1),
  standard('Standard', 3),
  large('Large', 10),
  maximum('Maximum', 30);

  const BufferMode(this.label, this.seconds);

  final String label;
  final int seconds;
}

class DecoderConfig {
  final DecoderMode decoderMode;
  final BufferMode bufferMode;
  final String userAgent;

  const DecoderConfig({
    this.decoderMode = DecoderMode.auto,
    this.bufferMode = BufferMode.standard,
    this.userAgent = 'MegaV-IPTV/1.0',
  });

  bool get usesMedia3 => decoderMode.usesMedia3;

  DecoderConfig copyWith({DecoderMode? decoderMode, BufferMode? bufferMode, String? userAgent}) {
    return DecoderConfig(
      decoderMode: decoderMode ?? this.decoderMode,
      bufferMode: bufferMode ?? this.bufferMode,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  Map<String, String> get mpvProperties {
    String hwdec = decoderMode.hwdecValue.isEmpty ? 'auto' : decoderMode.hwdecValue;
    if (hwdec.startsWith('mediacodec') && !_isAndroid) {
      hwdec = 'auto';
    }
    return {
      'hwdec': hwdec,
      'cache': 'yes',
      'demuxer-max-bytes': '50MiB',
      'demuxer-max-back-bytes': '10MiB',
      'demuxer-readahead-secs': '${bufferMode.seconds}',
      'vd-lavc-threads': '0',
      'rtsp-transport': 'udp',
      'demuxer-lavf-probesize': '2097152',
      'demuxer-lavf-analyzeduration': '2',
      'http-header-fields': 'User-Agent: $userAgent',
    };
  }

  static bool get _isAndroid => Platform.isAndroid;
}
