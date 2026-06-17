import 'package:flutter/material.dart';

import '/flutter_flow/internationalization.dart';
import '/shared_pages/design/expatlio_design.dart';

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
          child: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'События',
              enText: 'Events',
            ),
            style: ExpatlioDesign.textStyle(
              context,
              size: 34,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
