import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/students_pages/favorite/favorite_widget.dart';

void main() {
  test('favorite chat rows expose a fixed total height', () {
    expect(favoriteChatRowHeight(), 77.0);
  });

  test('favorite chat row slots expose fixed dimensions', () {
    expect(favoriteChatAvatarSize(), 52.0);
    expect(favoriteChatTimestampWidth(), 74.0);
    expect(favoriteChatUnreadBadgeSize(), 30.0);
    expect(favoriteChatDividerThickness(), 1.0);
  });

  test('favorite unread badge label changes without changing badge size', () {
    expect(favoriteChatUnreadBadgeLabel(1), '1');
    expect(favoriteChatUnreadBadgeLabel(2), '2');
    expect(favoriteChatUnreadBadgeLabel(99), '99');
    expect(favoriteChatUnreadBadgeLabel(100), '99+');
    expect(favoriteChatUnreadBadgeSize(), 30.0);
  });

  test('favorite chat rows use one shared fixed-height frame', () {
    final source = File('lib/students_pages/favorite/favorite_widget.dart')
        .readAsStringSync();

    expect(source, contains('Widget _chatRowFrame'));
    expect(
        RegExp(r'child:\s*_chatRowFrame\(').allMatches(source), hasLength(2));
    expect(source, contains('height: _favoriteChatRowHeight'));
    expect(source, contains('height: _favoriteChatRowContentHeight'));
    expect(source, contains('height: _favoriteChatUnreadSlotHeight'));
    expect(source, contains('height: _favoriteChatDividerThickness'));
    expect(source, contains('thickness: _favoriteChatDividerThickness'));
    expect(source, contains('dimension: _favoriteChatUnreadBadgeSize'));
    expect(source, isNot(contains('switch (label.length)')));
    expect(source, isNot(contains('if (unread) ...[')));
  });

  test('favorite chat timestamp and badge slots do not scale row height', () {
    final source = File('lib/students_pages/favorite/favorite_widget.dart')
        .readAsStringSync();

    expect(source, contains('height: _favoriteChatRowContentHeight'));
    expect(source, contains('textScaler: TextScaler.noScaling'));
  });

  test('dynamically sorted chat lists remap keyed children', () {
    final source = File('lib/students_pages/favorite/favorite_widget.dart')
        .readAsStringSync();

    expect(RegExp(r'findChildIndexCallback:').allMatches(source), hasLength(2));
    expect(source, contains('inboxItemIndexByRowKey[key]'));
    expect(source, contains('friendConversationIndexByRowKey[key]'));
    expect(source, contains('_inboxItemAsyncRowKey'));
  });
}
