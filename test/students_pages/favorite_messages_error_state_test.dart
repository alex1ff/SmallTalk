import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/students_pages/favorite/favorite_widget.dart';

void main() {
  test('messages load error is visible before first complete chat load', () {
    expect(
      shouldShowFavoriteMessagesLoadError(
        conversationsLoadFailed: true,
        eventChatsLoadFailed: false,
        conversationsHasLoaded: false,
        eventChatsHasLoaded: true,
        inboxIsEmpty: true,
      ),
      isTrue,
    );
  });

  test('messages load error wins over waiting source before first data', () {
    expect(
      shouldShowFavoriteMessagesLoadError(
        conversationsLoadFailed: true,
        eventChatsLoadFailed: false,
        conversationsHasLoaded: false,
        eventChatsHasLoaded: false,
        inboxIsEmpty: true,
      ),
      isTrue,
    );
  });

  test('messages load error does not replace a loaded empty list', () {
    expect(
      shouldShowFavoriteMessagesLoadError(
        conversationsLoadFailed: true,
        eventChatsLoadFailed: false,
        conversationsHasLoaded: true,
        eventChatsHasLoaded: true,
        inboxIsEmpty: true,
      ),
      isFalse,
    );
  });

  test('messages load error does not replace loaded chat rows', () {
    expect(
      shouldShowFavoriteMessagesLoadError(
        conversationsLoadFailed: true,
        eventChatsLoadFailed: true,
        conversationsHasLoaded: false,
        eventChatsHasLoaded: false,
        inboxIsEmpty: false,
      ),
      isFalse,
    );
  });
}
