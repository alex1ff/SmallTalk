import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/events/event_create_widget.dart';
import '/shared_pages/design/expatlio_design.dart';

const ValueKey<String> eventListCreateButtonKey =
    ValueKey<String>('event_list_create_button');

class EventListWidget extends StatelessWidget {
  const EventListWidget({super.key});

  static String routeName = 'events';
  static String routePath = '/events';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: Padding(
          padding: ExpatlioDesign.pageScrollPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'События',
                    enText: 'Events',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    size: 34,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: ExpatlioDesign.space16),
              Tooltip(
                message: FFLocalizations.of(context).getVariableText(
                  ruText: 'Создать событие',
                  enText: 'Create event',
                ),
                child: FlutterFlowIconButton(
                  key: eventListCreateButtonKey,
                  borderColor: Colors.transparent,
                  borderRadius: 24,
                  buttonSize: 48,
                  fillColor: ExpatlioDesign.primary,
                  icon: const Icon(
                    Icons.add_sharp,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => context.pushNamed(
                    EventCreateWidget.routeName,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
