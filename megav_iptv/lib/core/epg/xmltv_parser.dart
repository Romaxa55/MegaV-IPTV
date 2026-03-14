import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../playlist/models/epg_channel.dart';
import '../playlist/models/epg_program.dart';

typedef XmltvResult = ({List<EpgChannel> channels, List<EpgProgram> programs});

Future<XmltvResult> parseXmltvInIsolate(Uint8List gzippedData) {
  return Isolate.run(() => _parseXmltv(gzippedData));
}

XmltvResult _parseXmltv(Uint8List gzippedData) {
  final decompressed = gzip.decode(gzippedData);
  final xmlString = utf8.decode(decompressed, allowMalformed: true);
  final document = XmlDocument.parse(xmlString);
  final tv = document.rootElement;

  final channels = <EpgChannel>[];
  final programs = <EpgProgram>[];

  for (final element in tv.childElements) {
    switch (element.name.local) {
      case 'channel':
        final ch = _parseChannel(element);
        if (ch != null) channels.add(ch);
      case 'programme':
        final prog = _parseProgramme(element);
        if (prog != null) programs.add(prog);
    }
  }

  return (channels: channels, programs: programs);
}

EpgChannel? _parseChannel(XmlElement el) {
  final id = el.getAttribute('id');
  if (id == null || id.isEmpty) return null;

  final displayNameEl = el.getElement('display-name');
  final displayName = displayNameEl?.innerText ?? id;

  final iconEl = el.getElement('icon');
  final icon = iconEl?.getAttribute('src');

  return EpgChannel(id: id, displayName: displayName, icon: icon);
}

EpgProgram? _parseProgramme(XmlElement el) {
  final channelId = el.getAttribute('channel');
  final startStr = el.getAttribute('start');
  final stopStr = el.getAttribute('stop');

  if (channelId == null || startStr == null || stopStr == null) return null;

  final start = _parseXmltvDateTime(startStr);
  final stop = _parseXmltvDateTime(stopStr);
  if (start == null || stop == null) return null;

  final titleEl = el.getElement('title');
  final title = titleEl?.innerText ?? '';
  if (title.isEmpty) return null;

  final descEl = el.getElement('desc');
  final description = descEl?.innerText;

  final categoryEl = el.getElement('category');
  final category = categoryEl?.innerText;

  final iconEl = el.getElement('icon');
  final icon = iconEl?.getAttribute('src');

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

/// Parses XMLTV datetime: "20260314120000 +0300" or "20260314120000"
DateTime? _parseXmltvDateTime(String raw) {
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
