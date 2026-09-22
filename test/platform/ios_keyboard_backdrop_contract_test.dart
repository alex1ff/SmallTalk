import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter root paints an opaque keyboard backdrop', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('color: ExpatlioDesign.background'));
    expect(source, contains('ColoredBox'));
  });

  test('iOS reapplies the light window backdrop across startup lifecycle', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('applyKeyboardBackdrop'));
    expect(source, contains('window?.backgroundColor'));
    expect(source, contains('rootViewController?.view.backgroundColor'));
    expect(source, contains('applicationDidBecomeActive'));
    expect(source, contains('DispatchQueue.main.async'));
  });
}
