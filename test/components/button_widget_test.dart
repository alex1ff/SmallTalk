import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/button/button_widget.dart';
import 'package:small_talk/components/wrapper.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';

const _footerIgnoreKey = ValueKey<String>('call_summary_footer_ignore');
const _footerOpacityKey = ValueKey<String>('call_summary_footer_opacity');

class _CallSummaryFooterHarness extends StatefulWidget {
  const _CallSummaryFooterHarness({
    required this.onTap,
    this.bottomInset = 0.0,
  });

  final Future<void> Function() onTap;
  final double bottomInset;

  @override
  State<_CallSummaryFooterHarness> createState() =>
      _CallSummaryFooterHarnessState();
}

class _CallSummaryFooterHarnessState extends State<_CallSummaryFooterHarness> {
  late final FocusNode _focusNode = FocusNode()
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isComposerActive = _focusNode.hasFocus || widget.bottomInset > 0.0;

    return GestureDetector(
      key: const ValueKey<String>('outside_tap_area'),
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          TextField(
            focusNode: _focusNode,
          ),
          const Spacer(),
          SizedBox(
            height: 120.0,
            child: Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsetsDirectional.fromSTEB(
                  0.0,
                  0.0,
                  0.0,
                  isComposerActive ? 24.0 : 0.0,
                ),
                child: IgnorePointer(
                  key: _footerIgnoreKey,
                  ignoring: isComposerActive,
                  child: AnimatedOpacity(
                    key: _footerOpacityKey,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    opacity: isComposerActive ? 0.0 : 1.0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      offset: isComposerActive
                          ? const Offset(0.0, 0.24)
                          : Offset.zero,
                      child: Wrapper(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          6.0,
                          0.0,
                          6.0,
                          35.0,
                        ),
                        child: ButtonWidget(
                          text: 'Done',
                          action: widget.onTap,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  Widget buildHarness(
    Widget child, {
    double bottomInset = 0.0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: bottomInset),
          ),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }

  testWidgets('spinner mode shows loading UI and blocks repeat taps',
      (tester) async {
    final completer = Completer<void>();
    var tapCount = 0;

    await tester.pumpWidget(
      buildHarness(
        ButtonWidget(
          text: 'Submit',
          loadingText: 'Sending...',
          busyStyle: ButtonBusyStyle.spinner,
          action: () async {
            tapCount++;
            await completer.future;
          },
        ),
      ),
    );

    await tester.tap(find.byType(ButtonWidget));
    await tester.pump();

    expect(tapCount, 1);
    expect(find.text('Sending...'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('button_widget_spinner')),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(ButtonWidget));
    await tester.pump();
    expect(tapCount, 1);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Submit'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('debounceOnly mode blocks repeat taps without showing spinner',
      (tester) async {
    final completer = Completer<void>();
    var tapCount = 0;

    await tester.pumpWidget(
      buildHarness(
        ButtonWidget(
          text: 'Next',
          busyStyle: ButtonBusyStyle.debounceOnly,
          action: () async {
            tapCount++;
            await completer.future;
          },
        ),
      ),
    );

    await tester.tap(find.byType(ButtonWidget));
    await tester.pump();

    expect(tapCount, 1);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byType(ButtonWidget));
    await tester.pump();
    expect(tapCount, 1);

    completer.complete();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ButtonWidget));
    await tester.pump();
    expect(tapCount, 2);
  });

  testWidgets(
      'keyboard-aware wrapper padding reacts to MediaQuery viewInsets immediately',
      (tester) async {
    await tester.pumpWidget(
      buildHarness(
        Wrapper.keyboardAware(
          child: ButtonWidget(
            text: 'Continue',
            action: () async {},
          ),
        ),
      ),
    );

    var animatedPadding =
        tester.widget<AnimatedPadding>(find.byType(AnimatedPadding).first);
    expect(
      animatedPadding.padding.resolve(TextDirection.ltr).bottom,
      ExpatlioDesign.space32,
    );

    await tester.pumpWidget(
      buildHarness(
        Wrapper.keyboardAware(
          child: ButtonWidget(
            text: 'Continue',
            action: () async {},
          ),
        ),
        bottomInset: 280.0,
      ),
    );

    animatedPadding =
        tester.widget<AnimatedPadding>(find.byType(AnimatedPadding).first);
    expect(
      animatedPadding.padding.resolve(TextDirection.ltr).bottom,
      ExpatlioDesign.space8,
    );
  });

  testWidgets(
      'call summary footer stays mounted, becomes non-interactive while active, and returns immediately after unfocus',
      (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      buildHarness(
        _CallSummaryFooterHarness(
          bottomInset: 220.0,
          onTap: () async {
            tapCount++;
          },
        ),
      ),
    );

    expect(find.byType(ButtonWidget), findsOneWidget);
    expect(
      tester.widget<IgnorePointer>(find.byKey(_footerIgnoreKey)).ignoring,
      isTrue,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byKey(_footerOpacityKey)).opacity,
      0.0,
    );

    await tester.pumpWidget(
      buildHarness(
        _CallSummaryFooterHarness(
          onTap: () async {
            tapCount++;
          },
        ),
      ),
    );

    expect(find.byType(ButtonWidget), findsOneWidget);
    expect(
      tester.widget<IgnorePointer>(find.byKey(_footerIgnoreKey)).ignoring,
      isFalse,
    );

    await tester.tap(find.byType(ButtonWidget));
    await tester.pump();
    expect(tapCount, 1);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.byType(ButtonWidget), findsOneWidget);
    expect(
      tester.widget<IgnorePointer>(find.byKey(_footerIgnoreKey)).ignoring,
      isTrue,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byKey(_footerOpacityKey)).opacity,
      0.0,
    );

    await tester.tap(find.byType(ButtonWidget), warnIfMissed: false);
    await tester.pump();
    expect(tapCount, 1);

    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();

    expect(find.byType(ButtonWidget), findsOneWidget);
    expect(
      tester.widget<IgnorePointer>(find.byKey(_footerIgnoreKey)).ignoring,
      isFalse,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byKey(_footerOpacityKey)).opacity,
      1.0,
    );
  });
}
