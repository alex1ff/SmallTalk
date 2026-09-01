import 'package:flutter/material.dart';

import '../../shared_pages/design/expatlio_design.dart';
import 'session_limit_ui.dart' show formatCallTimerDuration;

const callDurationBadgeKey = ValueKey<String>('call_duration_badge');

/// Presentation-only badge for elapsed call time or remaining limit time.
class CallDurationBadge extends StatelessWidget {
  const CallDurationBadge({
    super.key,
    required this.displaySeconds,
    required this.hasCountdown,
    required this.isWarning,
  }) : assert(!isWarning || hasCountdown);

  final int displaySeconds;
  final bool hasCountdown;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final accentColor = isWarning ? const Color(0xFFFFB020) : Colors.white;

    return RepaintBoundary(
      child: Container(
        key: callDurationBadgeKey,
        padding: const EdgeInsets.symmetric(
          horizontal: ExpatlioDesign.space12,
          vertical: ExpatlioDesign.space8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: isWarning ? 0.68 : 0.45),
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
          border: hasCountdown
              ? Border.all(
                  color: accentColor.withValues(alpha: 0.44),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCountdown) ...[
              Icon(
                Icons.timer_outlined,
                color: accentColor,
                size: 16,
              ),
              const SizedBox(width: ExpatlioDesign.space8),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCallTimerDuration(displaySeconds),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    height: 1,
                  ),
                ),
                if (hasCountdown) ...[
                  const SizedBox(height: ExpatlioDesign.space4),
                  Text(
                    isWarning ? 'Осталась 1 минута до лимита' : 'до лимита',
                    style: TextStyle(
                      color: (isWarning ? accentColor : Colors.white)
                          .withValues(alpha: isWarning ? 0.95 : 0.72),
                      fontSize: 11,
                      fontWeight: isWarning ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.2,
                      height: 1,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
