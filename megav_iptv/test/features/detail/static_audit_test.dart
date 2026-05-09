import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('No BackdropFilter/ShaderMask/ImageFilter.blur in lib/features/detail/', () {
    final dir = Directory('lib/features/detail');
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    expect(files.isNotEmpty, isTrue, reason: 'Expected at least one .dart file in lib/features/detail/');

    final forbidden = RegExp(r'BackdropFilter|ShaderMask|ImageFilter\.blur');
    final commentLine = RegExp(r'^\s*///');

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (commentLine.hasMatch(line)) continue;
        expect(
          forbidden.hasMatch(line),
          isFalse,
          reason: '${file.path}:${i + 1}: forbidden perf-killer in code: "$line"',
        );
      }
    }
  });

  test('No blurRadius >= 13 in lib/features/detail/', () {
    final dir = Directory('lib/features/detail');
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    final pattern = RegExp(r'blurRadius:\s*(\d+)');
    final commentLine = RegExp(r'^\s*///');

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (commentLine.hasMatch(line)) continue;
        for (final match in pattern.allMatches(line)) {
          final n = int.parse(match.group(1)!);
          expect(n < 13, isTrue,
              reason: '${file.path}:${i + 1}: blurRadius >= 13 ($n) in: "$line"');
        }
      }
    }
  });
}
