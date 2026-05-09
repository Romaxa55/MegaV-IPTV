import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/theme/app_radius.dart';

void main() {
  group('AppRadius scale', () {
    test('xs == 6', () => expect(AppRadius.xs, 6));
    test('sm == 10', () => expect(AppRadius.sm, 10));
    test('md == 14', () => expect(AppRadius.md, 14));
    test('lg == 20', () => expect(AppRadius.lg, 20));
    test('xl == 28', () => expect(AppRadius.xl, 28));

    test('brSm equals BorderRadius.circular(10)', () {
      expect(AppRadius.brSm.topLeft.x, 10);
      expect(AppRadius.brSm.topRight.x, 10);
      expect(AppRadius.brSm.bottomLeft.x, 10);
      expect(AppRadius.brSm.bottomRight.x, 10);
    });

    test('all br* helpers exist as BorderRadius', () {
      expect(AppRadius.brXs, isA<BorderRadius>());
      expect(AppRadius.brSm, isA<BorderRadius>());
      expect(AppRadius.brMd, isA<BorderRadius>());
      expect(AppRadius.brLg, isA<BorderRadius>());
      expect(AppRadius.brXl, isA<BorderRadius>());
    });

    test('br* values match scale doubles', () {
      expect(AppRadius.brXs.topLeft.x, AppRadius.xs);
      expect(AppRadius.brSm.topLeft.x, AppRadius.sm);
      expect(AppRadius.brMd.topLeft.x, AppRadius.md);
      expect(AppRadius.brLg.topLeft.x, AppRadius.lg);
      expect(AppRadius.brXl.topLeft.x, AppRadius.xl);
    });
  });
}
