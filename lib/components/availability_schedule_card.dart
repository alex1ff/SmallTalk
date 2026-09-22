import '/backend/schema/structs/intervals_struct.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class AvailabilityScheduleCard extends StatelessWidget {
  const AvailabilityScheduleCard({
    super.key,
    required this.availabilityEnabled,
    required this.intervals,
    this.switchControl,
    required this.onAddInterval,
    required this.onRemoveInterval,
  });

  final bool availabilityEnabled;
  final List<IntervalsStruct> intervals;
  final Widget? switchControl;
  final Future<void> Function() onAddInterval;
  final Future<void> Function(IntervalsStruct interval) onRemoveInterval;

  @override
  Widget build(BuildContext context) {
    final switchControl = this.switchControl;
    final children = <Widget>[
      if (switchControl != null)
        _AvailabilitySwitchRow(switchControl: switchControl),
    ];

    if (availabilityEnabled) {
      for (final interval in intervals) {
        if (children.isNotEmpty) {
          children.add(const _AvailabilityDivider());
        }
        children.add(_AvailabilityIntervalRow(
          interval: interval,
          onRemoveInterval: onRemoveInterval,
        ));
      }

      if (children.isNotEmpty) {
        children.add(const _AvailabilityDivider());
      }
      children.add(_AvailabilityAddRow(onAddInterval: onAddInterval));
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: ExpatlioDesign.cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _AvailabilitySwitchRow extends StatelessWidget {
  const _AvailabilitySwitchRow({
    required this.switchControl,
  });

  final Widget switchControl;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60.0),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space16,
          ExpatlioDesign.space8,
          ExpatlioDesign.space12,
          ExpatlioDesign.space8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                FFLocalizations.of(context).getText(
                  'n1zbzn9y' /* Доступен сегодня */,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 16.0,
                ),
              ),
            ),
            const SizedBox(width: ExpatlioDesign.space12),
            switchControl,
          ],
        ),
      ),
    );
  }
}

class _AvailabilityIntervalRow extends StatelessWidget {
  const _AvailabilityIntervalRow({
    required this.interval,
    required this.onRemoveInterval,
  });

  final IntervalsStruct interval;
  final Future<void> Function(IntervalsStruct interval) onRemoveInterval;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56.0),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space12,
          ExpatlioDesign.space8,
          ExpatlioDesign.space8,
          ExpatlioDesign.space8,
        ),
        child: Row(
          children: [
            Container(
              width: 36.0,
              height: 36.0,
              decoration: ExpatlioDesign.softPrimaryDecoration(
                radius: ExpatlioDesign.radiusMedium,
              ),
              child: const Icon(
                FFIcons.kclock,
                color: ExpatlioDesign.primary,
                size: 18.0,
              ),
            ),
            const SizedBox(width: ExpatlioDesign.space12),
            Expanded(
              child: Text(
                '${interval.start} - ${interval.end}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 16.0,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            Tooltip(
              message: FFLocalizations.of(context).getVariableText(
                ruText: 'Удалить интервал',
                enText: 'Remove interval',
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.radiusMedium),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusMedium),
                  onTap: () async {
                    await onRemoveInterval(interval);
                  },
                  child: const SizedBox(
                    width: 40.0,
                    height: 40.0,
                    child: Icon(
                      FFIcons.ktrash03,
                      color: ExpatlioDesign.danger,
                      size: 18.0,
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

class _AvailabilityAddRow extends StatelessWidget {
  const _AvailabilityAddRow({
    required this.onAddInterval,
  });

  final Future<void> Function() onAddInterval;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.space8,
        ExpatlioDesign.space8,
        ExpatlioDesign.space8,
        ExpatlioDesign.space8,
      ),
      child: Material(
        color: ExpatlioDesign.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
          onTap: () async {
            await onAddInterval();
          },
          child: SizedBox(
            height: 48.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28.0,
                  height: 28.0,
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.primary.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: ExpatlioDesign.primary,
                    size: 20.0,
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space8),
                Text(
                  FFLocalizations.of(context).getText(
                    'ws9tu06c' /* Добавить интервал */,
                  ),
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.primary,
                    size: 15.0,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityDivider extends StatelessWidget {
  const _AvailabilityDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1.0,
      thickness: 1.0,
      indent: ExpatlioDesign.space16,
      endIndent: ExpatlioDesign.space16,
      color: ExpatlioDesign.border.withValues(alpha: 0.45),
    );
  }
}
