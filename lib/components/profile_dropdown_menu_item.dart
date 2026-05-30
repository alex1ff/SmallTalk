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
      margin: const EdgeInsetsDirectional.fromSTEB(8.0, 3.0, 8.0, 3.0),
      padding: const EdgeInsetsDirectional.fromSTEB(12.0, 7.0, 10.0, 7.0),
      decoration: BoxDecoration(
        color: selected
            ? ExpatlioDesign.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10.0),
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
            const SizedBox(width: 10.0),
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
