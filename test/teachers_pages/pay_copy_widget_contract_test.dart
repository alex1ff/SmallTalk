import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher finance add-card row has no nested icon tap target', () {
    final source = File('lib/teachers_pages/pay_copy/pay_copy_widget.dart')
        .readAsStringSync();

    const addCardLabel = "'ljhzclav' /* Добавить карту */";
    final labelIndex = source.indexOf(addCardLabel);
    expect(labelIndex, isNonNegative);

    final blockStart = source.lastIndexOf('child: InkWell(', labelIndex);
    final blockEnd =
        source.indexOf("'qpndbc1w' /* История операций */", labelIndex);
    expect(blockStart, isNonNegative);
    expect(blockEnd, isNonNegative);

    final addCardBlock = source.substring(blockStart, blockEnd);

    expect(addCardBlock, contains('onTap: () async {'));
    expect(addCardBlock, contains('child: AddCardWidget(),'));
    expect(addCardBlock, isNot(contains('FlutterFlowIconButton(')));
    expect(addCardBlock, isNot(contains('onPressed:')));
  });
}
