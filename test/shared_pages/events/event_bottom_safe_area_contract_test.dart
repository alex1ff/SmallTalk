import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event screens let sticky bottom bars own the bottom safe area', () {
    final chatSource =
        File('lib/shared_pages/events/event_group_chat_widget.dart')
            .readAsStringSync();
    final detailSource =
        File('lib/shared_pages/events/event_detail_widget.dart')
            .readAsStringSync();
    final createSource =
        File('lib/shared_pages/events/event_create_widget.dart')
            .readAsStringSync();

    expect(
        chatSource, contains(RegExp(r'body:\s+SafeArea\(\s+bottom: false,')));
    expect(
      detailSource,
      contains(RegExp(r'body:\s+SafeArea\(\s+bottom: false,')),
    );
    expect(
      createSource,
      contains(RegExp(r'body:\s+SafeArea\(\s+bottom: false,')),
    );
    expect(
      createSource,
      contains(
        RegExp(
          r'class _EventCreateSubmitBar[\s\S]*child: SafeArea\(\s+top: false,',
        ),
      ),
    );
  });
}
