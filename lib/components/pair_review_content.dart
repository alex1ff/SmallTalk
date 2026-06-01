import '/flutter_flow/flutter_flow_theme.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import 'package:flutter/material.dart';

class PairReviewContent extends StatelessWidget {
  const PairReviewContent({
    super.key,
    required this.hasReviewed,
    required this.formContent,
    this.reviewContent,
    this.reviewNoteText,
    this.reviewFallbackText,
  });

  final bool hasReviewed;
  final Widget formContent;
  final Widget? reviewContent;
  final String? reviewNoteText;
  final String? reviewFallbackText;

  @override
  Widget build(BuildContext context) {
    if (!hasReviewed) {
      return formContent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reviewNoteText != null && reviewNoteText!.trim().isNotEmpty) ...[
          _PairReviewInfoCard(message: reviewNoteText!),
          const SizedBox(height: ExpatlioDesign.space12),
        ],
        reviewContent ??
            _PairReviewInfoCard(
              message: reviewFallbackText ?? reviewAlreadyLeftMessage(context),
            ),
      ],
    );
  }
}

class _PairReviewInfoCard extends StatelessWidget {
  const _PairReviewInfoCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ExpatlioDesign.space16),
        child: Text(
          message,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'sf pro display',
                fontSize: 15.0,
                letterSpacing: 0.0,
              ),
        ),
      ),
    );
  }
}
