import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/outgoing_caption_buffer.dart';

void main() {
  test('second enqueue replaces first and take returns latest once', () {
    final buffer = OutgoingCaptionBuffer<String>();
    buffer.enqueue('first', 'sig-1');
    buffer.enqueue('second', 'sig-2');
    expect(buffer.takePending(), (value: 'second', signature: 'sig-2'));
    expect(buffer.takePending(), isNull);
  });

  test('signature travels atomically with its value', () {
    final buffer = OutgoingCaptionBuffer<int>();
    buffer.enqueue(1, 'first');
    buffer.enqueue(2, 'second');
    final item = buffer.takePending()!;
    expect(item.value, 2);
    expect(item.signature, 'second');
  });

  test('duplicate is suppressed only after successful mark', () {
    final buffer = OutgoingCaptionBuffer<String>();
    expect(buffer.isDuplicate('same'), isFalse);
    buffer.enqueue('message', 'same');
    expect(buffer.takePending(), isNotNull);
    expect(buffer.isDuplicate('same'), isFalse);
    buffer.markSent('same');
    expect(buffer.isDuplicate('same'), isTrue);
    expect(buffer.isDuplicate('different'), isFalse);
  });

  test('failed send leaves same signature eligible for a later enqueue', () {
    final buffer = OutgoingCaptionBuffer<String>();
    buffer.enqueue('first attempt', 'same');
    final failed = buffer.takePending()!;
    expect(buffer.isDuplicate(failed.signature), isFalse);
    buffer.enqueue('second attempt', 'same');
    expect(buffer.takePending(), (value: 'second attempt', signature: 'same'));
    expect(buffer.isDuplicate('same'), isFalse);
  });

  test('overlapping takes remain independent and completion order wins mark',
      () {
    final buffer = OutgoingCaptionBuffer<String>();
    buffer.enqueue('interim', 'interim-signature');
    final interim = buffer.takePending()!;
    buffer.enqueue('final', 'final-signature');
    final finalMessage = buffer.takePending()!;

    buffer.markSent(finalMessage.signature);
    expect(buffer.isDuplicate('final-signature'), isTrue);
    buffer.markSent(interim.signature);
    expect(buffer.isDuplicate('interim-signature'), isTrue);
    expect(buffer.isDuplicate('final-signature'), isFalse);
  });

  test('clear resets pending and successful signature', () {
    final buffer = OutgoingCaptionBuffer<String>();
    buffer.enqueue('pending', 'pending-sig');
    buffer.markSent('sent-sig');
    buffer.clear();
    expect(buffer.takePending(), isNull);
    expect(buffer.isDuplicate('sent-sig'), isFalse);
    buffer.enqueue('new session', 'sent-sig');
    expect(buffer.takePending(), (value: 'new session', signature: 'sent-sig'));
  });

  test('instances do not share pending or duplicate state', () {
    final first = OutgoingCaptionBuffer<String>();
    final second = OutgoingCaptionBuffer<String>();
    first.enqueue('one', 'sig');
    first.markSent('sent');
    expect(second.takePending(), isNull);
    expect(second.isDuplicate('sent'), isFalse);
    second.enqueue('two', 'other');
    expect(first.takePending(), (value: 'one', signature: 'sig'));
    expect(second.takePending(), (value: 'two', signature: 'other'));
  });
}
