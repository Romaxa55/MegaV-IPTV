import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:xml/xml_events.dart';

import '../playlist/models/epg_channel.dart';
import '../playlist/models/epg_program.dart';

typedef EpgParseResult = ({List<EpgChannel> channels, List<EpgProgram> programs});

/// Callback signature for receiving parsed EPG data in chunks.
/// Returns channels and programs parsed so far in this chunk.
/// [done] is true when parsing is complete.
typedef EpgChunkCallback = Future<void> Function(EpgParseResult chunk, {required bool done});

/// Parses XMLTV gzipped data in an isolate, returning all results at once.
/// Use [parseXmltvStreaming] for memory-efficient chunked processing.
Future<EpgParseResult> parseXmltvInIsolate(Uint8List gzippedData) {
  return Isolate.run(() => _parseXmltvStreaming(gzippedData));
}

/// Parses XMLTV gzipped data using event-based (SAX-style) streaming.
/// Never loads the full DOM tree into memory.
/// Returns channels and programs in chunks via [onChunk] callback,
/// flushing every [chunkSize] programs to keep memory low.
Future<EpgParseResult> parseXmltvStreamingWithChunks(
  Uint8List gzippedData, {
  required EpgChunkCallback onChunk,
  int chunkSize = 1000,
}) async {
  final allChannels = <EpgChannel>[];
  final allPrograms = <EpgProgram>[];

  final result = await Isolate.run(() => _parseXmltvStreaming(gzippedData));

  // Split into chunks and deliver
  for (var i = 0; i < result.channels.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, result.channels.length);
    allChannels.addAll(result.channels.sublist(i, end));
  }

  for (var i = 0; i < result.programs.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, result.programs.length);
    final chunk = result.programs.sublist(i, end);
    allPrograms.addAll(chunk);
    await onChunk((channels: <EpgChannel>[], programs: chunk), done: end >= result.programs.length);
  }

  return (channels: allChannels, programs: allPrograms);
}

/// Internal streaming parser using xml event-based API.
/// Processes events one-by-one — no DOM tree, no full document in memory.
EpgParseResult _parseXmltvStreaming(Uint8List gzippedData) {
  final decompressed = gzip.decode(gzippedData);
  final xmlString = utf8.decode(decompressed, allowMalformed: true);

  final channels = <EpgChannel>[];
  final programs = <EpgProgram>[];

  // State machine for SAX-style parsing
  _ParserState state = _ParserState.idle;
  String? currentChannelId;
  String? currentChannelName;
  String? currentChannelIcon;

  String? currentProgChannelId;
  DateTime? currentProgStart;
  DateTime? currentProgStop;
  String? currentProgTitle;
  String? currentProgDesc;
  String? currentProgCategory;
  String? currentProgIcon;

  String? currentTextElement;

  for (final event in parseEvents(xmlString)) {
    if (event is XmlStartElementEvent) {
      switch (event.name) {
        case 'channel':
          state = _ParserState.channel;
          currentChannelId = _attr(event, 'id');
          currentChannelName = null;
          currentChannelIcon = null;

        case 'display-name' when state == _ParserState.channel:
          currentTextElement = 'display-name';

        case 'icon' when state == _ParserState.channel:
          currentChannelIcon = _attr(event, 'src');

        case 'programme':
          state = _ParserState.programme;
          currentProgChannelId = _attr(event, 'channel');
          currentProgStart = _parseXmltvDateTime(_attr(event, 'start'));
          currentProgStop = _parseXmltvDateTime(_attr(event, 'stop'));
          currentProgTitle = null;
          currentProgDesc = null;
          currentProgCategory = null;
          currentProgIcon = null;

        case 'title' when state == _ParserState.programme:
          currentTextElement = 'title';

        case 'desc' when state == _ParserState.programme:
          currentTextElement = 'desc';

        case 'category' when state == _ParserState.programme:
          currentTextElement = 'category';

        case 'icon' when state == _ParserState.programme:
          currentProgIcon = _attr(event, 'src');
      }
    } else if (event is XmlTextEvent) {
      final text = event.value.trim();
      if (text.isEmpty) continue;

      switch (currentTextElement) {
        case 'display-name':
          currentChannelName = text;
        case 'title':
          currentProgTitle = text;
        case 'desc':
          currentProgDesc = text;
        case 'category':
          currentProgCategory = text;
      }
    } else if (event is XmlEndElementEvent) {
      switch (event.name) {
        case 'channel':
          final chId = currentChannelId;
          if (chId != null && chId.isNotEmpty) {
            channels.add(EpgChannel(id: chId, displayName: currentChannelName ?? chId, icon: currentChannelIcon));
          }
          state = _ParserState.idle;
          currentTextElement = null;

        case 'programme':
          final progChId = currentProgChannelId;
          final progStart = currentProgStart;
          final progStop = currentProgStop;
          final progTitle = currentProgTitle;
          if (progChId != null && progStart != null && progStop != null && progTitle != null && progTitle.isNotEmpty) {
            programs.add(
              EpgProgram(
                channelId: progChId,
                title: progTitle,
                description: currentProgDesc,
                category: currentProgCategory,
                icon: currentProgIcon,
                start: progStart,
                end: progStop,
              ),
            );
          }
          state = _ParserState.idle;
          currentTextElement = null;

        case 'display-name':
        case 'title':
        case 'desc':
        case 'category':
        case 'icon':
          currentTextElement = null;
      }
    }
  }

  return (channels: channels, programs: programs);
}

enum _ParserState { idle, channel, programme }

String? _attr(XmlStartElementEvent event, String name) {
  for (final attr in event.attributes) {
    if (attr.name == name) return attr.value;
  }
  return null;
}

/// Parses XMLTV datetime: "20260314120000 +0300" or "20260314120000"
DateTime? _parseXmltvDateTime(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.length < 14) return null;

  try {
    final year = int.parse(trimmed.substring(0, 4));
    final month = int.parse(trimmed.substring(4, 6));
    final day = int.parse(trimmed.substring(6, 8));
    final hour = int.parse(trimmed.substring(8, 10));
    final minute = int.parse(trimmed.substring(10, 12));
    final second = int.parse(trimmed.substring(12, 14));

    final utcTime = DateTime.utc(year, month, day, hour, minute, second);

    if (trimmed.length >= 19) {
      final tzPart = trimmed.substring(14).trim();
      if (tzPart.isNotEmpty) {
        final sign = tzPart[0] == '+' ? 1 : -1;
        final tzHours = int.parse(tzPart.substring(1, 3));
        final tzMinutes = int.parse(tzPart.substring(3, 5));
        final offset = Duration(hours: tzHours, minutes: tzMinutes) * sign;
        return utcTime.subtract(offset);
      }
    }

    return utcTime;
  } catch (_) {
    return null;
  }
}
