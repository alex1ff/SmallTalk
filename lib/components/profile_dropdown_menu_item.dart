import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class ProfileDropdownMenuItem extends StatelessWidget {
  const ProfileDropdownMenuItem({
    super.key,
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space8,
          ExpatlioDesign.space4, ExpatlioDesign.space8, ExpatlioDesign.space4),
      padding: const EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space12,
          ExpatlioDesign.space8, ExpatlioDesign.space12, ExpatlioDesign.space8),
      decoration: BoxDecoration(
        color: selected
            ? ExpatlioDesign.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.textStyle(
                context,
                size: 14.0,
                weight: FontWeight.w500,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: ExpatlioDesign.space12),
            const Icon(
              Icons.check_rounded,
              color: ExpatlioDesign.primary,
              size: 18.0,
            ),
          ],
        ],
      ),
    );
  }
}
