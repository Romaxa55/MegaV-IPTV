import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml_events.dart';

import '../playlist/models/epg_channel.dart';
import '../playlist/models/epg_program.dart';

/// Callback that receives a batch of parsed programs for immediate DB insertion.
typedef OnProgramBatch = Future<void> Function(List<EpgProgram> batch);

/// Callback that receives all parsed channels (called once after all channels parsed).
typedef OnChannelsParsed = Future<void> Function(List<EpgChannel> channels);

/// Fully streaming EPG parser with bounded memory.
///
/// Pipeline: File → gzip.decoder → utf8.decoder → element splitter → parse → DB
///
/// Instead of loading the entire XML into memory, this parser:
/// 1. Streams the gzipped file through decompression and UTF-8 decoding
/// 2. Extracts individual `<channel>` and `<programme>` XML elements
///    using a lightweight regex-free text scanner
/// 3. Parses each small element (~0.5-2 KB) with `parseEvents()`
/// 4. Flushes programs to the database every [batchSize] items
///
/// Peak memory: ~10-20 MB regardless of EPG file size.
Future<({int channels, int programs})> parseXmltvFromFile(
  String filePath, {
  required OnChannelsParsed onChannels,
  required OnProgramBatch onProgramBatch,
  int batchSize = 1000,
}) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw FileSystemException('EPG file not found', filePath);
  }

  final channels = <EpgChannel>[];
  final programBatch = <EpgProgram>[];
  int totalPrograms = 0;
  bool channelsFlushed = false;

  // Buffer for accumulating partial XML elements across stream chunks
  final elementBuffer = StringBuffer();
  bool insideElement = false;
  String? currentTag; // 'channel' or 'programme'

  Future<void> processElement(String xml, String tag) async {
    if (tag == 'channel') {
      final ch = _parseChannelElement(xml);
      if (ch != null) channels.add(ch);
    } else if (tag == 'programme') {
      // If we encounter the first programme and haven't flushed channels yet
      if (!channelsFlushed && channels.isNotEmpty) {
        await onChannels(channels);
        channelsFlushed = true;
      }

      final prog = _parseProgrammeElement(xml);
      if (prog != null) {
        programBatch.add(prog);
        totalPrograms++;

        if (programBatch.length >= batchSize) {
          await onProgramBatch(List.of(programBatch));
          programBatch.clear();
        }
      }
    }
  }

  // Stream pipeline: file → gzip → utf8 → String chunks
  final xmlStream = file.openRead().transform(gzip.decoder).transform(utf8.decoder);

  await for (final chunk in xmlStream) {
    int pos = 0;

    while (pos < chunk.length) {
      if (!insideElement) {
        // Scan for opening tag: <channel or <programme
        final channelStart = chunk.indexOf('<channel', pos);
        final programmeStart = chunk.indexOf('<programme', pos);

        int earliest = -1;
        String? tag;

        if (channelStart >= 0 && (programmeStart < 0 || channelStart < programmeStart)) {
          earliest = channelStart;
          tag = 'channel';
        } else if (programmeStart >= 0) {
          earliest = programmeStart;
          tag = 'programme';
        }

        if (earliest < 0) break; // no more elements in this chunk

        insideElement = true;
        currentTag = tag;
        elementBuffer.clear();
        pos = earliest;
      }

      if (insideElement) {
        // Scan for closing tag
        final closingTag = '</$currentTag>';
        final closingIdx = chunk.indexOf(closingTag, pos);

        if (closingIdx >= 0) {
          final endPos = closingIdx + closingTag.length;
          elementBuffer.write(chunk.substring(pos, endPos));
          await processElement(elementBuffer.toString(), currentTag!);
          elementBuffer.clear();
          insideElement = false;
          currentTag = null;
          pos = endPos;
        } else {
          // Closing tag not found in this chunk — buffer and continue
          elementBuffer.write(chunk.substring(pos));
          break;
        }
      }
    }
  }

  // Flush remaining channels if we never hit a <programme>
  if (!channelsFlushed && channels.isNotEmpty) {
    await onChannels(channels);
  }

  // Flush remaining programs
  if (programBatch.isNotEmpty) {
    await onProgramBatch(programBatch);
  }

  return (channels: channels.length, programs: totalPrograms);
}

// ---------------------------------------------------------------------------
// Per-element parsers using lightweight event-based XML
// ---------------------------------------------------------------------------

EpgChannel? _parseChannelElement(String xml) {
  String? id;
  String? displayName;
  String? icon;
  String? currentText;

  for (final event in parseEvents(xml)) {
    if (event is XmlStartElementEvent) {
      if (event.name == 'channel') {
        id = _attr(event, 'id');
      } else if (event.name == 'display-name') {
        currentText = 'display-name';
      } else if (event.name == 'icon') {
        icon = _attr(event, 'src');
      }
    } else if (event is XmlTextEvent && currentText == 'display-name') {
      final text = event.value.trim();
      if (text.isNotEmpty) displayName = text;
    } else if (event is XmlEndElementEvent) {
      currentText = null;
    }
  }

  if (id == null || id.isEmpty) return null;
  return EpgChannel(id: id, displayName: displayName ?? id, icon: icon);
}

EpgProgram? _parseProgrammeElement(String xml) {
  String? channelId;
  DateTime? start;
  DateTime? stop;
  String? title;
  String? description;
  String? category;
  String? icon;
  String? currentText;

  for (final event in parseEvents(xml)) {
    if (event is XmlStartElementEvent) {
      switch (event.name) {
        case 'programme':
          channelId = _attr(event, 'channel');
          start = _parseXmltvDateTime(_attr(event, 'start'));
          stop = _parseXmltvDateTime(_attr(event, 'stop'));
        case 'title':
          currentText = 'title';
        case 'desc':
          currentText = 'desc';
        case 'category':
          currentText = 'category';
        case 'icon':
          icon = _attr(event, 'src');
      }
    } else if (event is XmlTextEvent) {
      final text = event.value.trim();
      if (text.isEmpty) continue;
      switch (currentText) {
        case 'title':
          title = text;
        case 'desc':
          description = text;
        case 'category':
          category = text;
      }
    } else if (event is XmlEndElementEvent) {
      currentText = null;
    }
  }

  if (channelId == null || start == null || stop == null) return null;
  if (title == null || title.isEmpty) return null;

  return EpgProgram(
    channelId: channelId,
    title: title,
    description: description,
    category: category,
    icon: icon,
    start: start,
    end: stop,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
