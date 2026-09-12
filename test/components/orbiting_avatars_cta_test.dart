import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/orbiting_avatars_cta.dart';

void main() {
  test('avatar motion supports opposite directions, drift, and scale pulse',
      () {
    const clockwise = OrbitingAvatarMotionSpec(
      radiusX: 96.0,
      radiusY: 54.0,
      phase: 0.0,
      speed: 1.0,
      drift: 0.18,
      scalePulse: 0.18,
    );
    const counterClockwise = OrbitingAvatarMotionSpec(
      radiusX: 96.0,
      radiusY: 54.0,
      phase: 0.0,
      speed: -1.0,
      drift: 0.18,
      scalePulse: 0.18,
    );

    expect(clockwise.offsetAt(0.25).dy, greaterThan(0));
    expect(counterClockwise.offsetAt(0.25).dy, lessThan(0));

    final firstRadius = clockwise.offsetAt(0.10).distance;
    final laterRadius = clockwise.offsetAt(0.35).distance;
    expect((firstRadius - laterRadius).abs(), greaterThan(1.0));

    expect(
      (clockwise.scaleAt(0.0) - clockwise.scaleAt(0.25)).abs(),
      greaterThan(0.04),
    );
  });

  test('avatar motion loops seamlessly', () {
    const motion = OrbitingAvatarMotionSpec(
      radiusX: 128.0,
      radiusY: 74.0,
      phase: 2.6,
      speed: -0.74,
      drift: 0.18,
      scalePulse: 0.22,
    );

    expect(
        (motion.offsetAt(0.0) - motion.offsetAt(1.0)).distance, lessThan(0.01));
    expect((motion.scaleAt(0.0) - motion.scaleAt(1.0)).abs(), lessThan(0.001));
  });

  testWidgets('CTA keeps avatars behind the central action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390.0,
            height: 360.0,
            child: OrbitingAvatarsCta(
              avatars: [
                OrbitingAvatarData(
                  initials: 'AA',
                  motion: OrbitingAvatarMotionSpec(
                    radiusX: 96.0,
                    radiusY: 54.0,
                    phase: 0.0,
                    speed: 1.0,
                  ),
                ),
                OrbitingAvatarData(
                  initials: 'BB',
                  motion: OrbitingAvatarMotionSpec(
                    radiusX: 108.0,
                    radiusY: 70.0,
                    phase: 1.4,
                    speed: -0.8,
                  ),
                ),
              ],
              action: SizedBox(key: ValueKey<String>('central_action')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('central_action')), findsOneWidget);
  });
}
