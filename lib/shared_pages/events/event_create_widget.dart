import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';

class EventCreateWidget extends StatelessWidget {
  const EventCreateWidget({super.key});

  static String routeName = 'eventCreate';
  static String routePath = '/events/create';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _EventCreateTopBar(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(ExpatlioDesign.space24),
                  child: Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'Создать событие',
                      enText: 'Create event',
                    ),
                    textAlign: TextAlign.center,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 28,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCreateTopBar extends StatelessWidget {
  const _EventCreateTopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ExpatlioDesign.pageHeaderHeight,
      child: Row(
        children: [
          FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 24,
            buttonSize: 48,
            icon: Icon(
              FFIcons.kchevronLeft,
              color: ExpatlioDesign.text,
              size: 24,
            ),
            onPressed: () => context.safePop(),
          ),
          Expanded(
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Создать событие',
                enText: 'Create event',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.pageHeaderTitleStyle(context),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
