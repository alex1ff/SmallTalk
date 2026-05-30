import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_theme.dart';

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
        constraints: const BoxConstraints(maxWidth: 280.0),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 10.0),
          child: Material(
            color: FlutterFlowTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(24.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(24.0),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  16.0,
                  12.0,
                  16.0,
                  12.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: _resolvedIconColor(context),
                      size: 18.0,
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
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
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
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
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  fontSize: 12.0,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: FlutterFlowTheme.of(context).secondaryText,
                      size: 18.0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
