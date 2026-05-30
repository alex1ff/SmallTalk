import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class NativeSpeakerGroupedPageScaffold extends StatelessWidget {
  const NativeSpeakerGroupedPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.pagePadding,
        20.0,
        ExpatlioDesign.pagePadding,
        130.0,
      ),
      children: [
        Text(
          title,
          style: ExpatlioDesign.textStyle(
            context,
            size: 34.0,
            weight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          subtitle,
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.muted,
            size: 15.0,
          ),
        ),
        const SizedBox(height: 22.0),
        child,
      ],
    );
  }
}
