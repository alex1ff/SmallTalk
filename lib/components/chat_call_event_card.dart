import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/shared_pages/design/expatlio_design.dart';

enum ChatCallEventTone {
  normal,
  alert,
}

class ChatCallEventCard extends StatelessWidget {
  const ChatCallEventCard({
    super.key,
    required this.title,
    required this.details,
    this.icon = Icons.phone_rounded,
    this.tone = ChatCallEventTone.normal,
    this.onTap,
  });

  final String title;
  final String details;
  final IconData icon;
  final ChatCallEventTone tone;
  final VoidCallback? onTap;

  Color _resolvedIconColor(BuildContext context) {
    return switch (tone) {
      ChatCallEventTone.normal => FlutterFlowTheme.of(context).primary,
      ChatCallEventTone.alert => FlutterFlowTheme.of(context).error,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 244.0),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 12.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ExpatlioDesign.card,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: ExpatlioDesign.border),
              boxShadow: ExpatlioDesign.cardShadow,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(14.0),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    16.0,
                    10.0,
                    16.0,
                    10.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32.0,
                        height: 32.0,
                        decoration: BoxDecoration(
                          color: _resolvedIconColor(context)
                              .withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          icon,
                          color: _resolvedIconColor(context),
                          size: 17.0,
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: ExpatlioDesign.text,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              details,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: ExpatlioDesign.muted,
                                    fontSize: 12.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
