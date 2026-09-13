import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/shared_pages/events/event_list_widget.dart')
        .readAsStringSync();
  });

  test('Events keeps page loading lazy and bounded', () {
    expect(source, contains('const int _eventListPageSize = 20;'));
    expect(source, contains('_eventListPaginationPrefetchExtent'));
    expect(source, contains('position.extentAfter'));
    expect(source, contains('session.requestInFlight'));
    expect(source, contains('_loadNextEventPage(session)'));
    expect(source, contains('pageSize: _eventListPageSize'));
  });

  test('Events rejects duplicate or stale pagination responses', () {
    expect(source, contains('knownEventIds'));
    expect(source, contains('knownEventIds.add(event.reference.id)'));
    expect(source, contains('cursorDidNotAdvance'));
    expect(
        source, contains('identical(session.nextPageMarker, requestMarker)'));
    expect(source, contains('_eventListPaginationSessionIsCurrent(session)'));
  });

  test('Events lazily builds loaded cards with stable repaint boundaries', () {
    expect(source, contains('class _EventListCardsSliver'));
    expect(source, contains('CustomScrollView('));
    expect(source, contains('SliverChildBuilderDelegate('));
    expect(source, contains('findChildIndexCallback:'));
    expect(source, contains('eventCardsSemanticCount(eventsSnapshot)'));
    expect(source, contains('semanticIndexCallback:'));
    expect(source, contains('index.isEven ? index ~/ 2 : null'));
    expect(source, contains("'event_list_lazy_\${eventCard.eventId}'"));
    expect(source, contains('RepaintBoundary('));
  });
}
