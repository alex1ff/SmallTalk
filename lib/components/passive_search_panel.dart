import 'package:flutter/material.dart';

import '/flutter_flow/internationalization.dart';
import '/services/passive_search_service.dart';
import '/shared_pages/design/expatlio_design.dart';

class PassiveSearchPanel extends StatelessWidget {
  const PassiveSearchPanel({
    super.key,
    required this.onChoose,
    this.expiresAt,
    this.busy = false,
    this.error,
  });

  final ValueChanged<PassiveSearchDuration> onChoose;
  final DateTime? expiresAt;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final localizations = FFLocalizations.of(context);
    final localEnd = expiresAt?.toLocal();
    final endLabel = localEnd == null
        ? ''
        : '${localEnd.hour.toString().padLeft(2, '0')}:${localEnd.minute.toString().padLeft(2, '0')}';
    return Container(
      key: const ValueKey('passive-search-panel'),
      constraints: const BoxConstraints(maxWidth: 340),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ExpatlioDesign.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localEnd == null
                ? localizations.getVariableText(
                    ruText:
                        'Сейчас все собеседники заняты. Вы можете встать в очередь — приложение можно закрыть, мы уведомим вас.',
                    enText:
                        'All partners are busy right now. You can join the waiting list and close the app. We’ll notify you.',
                  )
                : localizations.getVariableText(
                    ruText:
                        'Вы в очереди до $endLabel. Приложение можно закрыть — мы уведомим вас о новых собеседниках.',
                    enText:
                        'You’re on the waiting list until $endLabel. You can close the app. We’ll notify you when a partner is available.',
                  ),
            textAlign: TextAlign.center,
            style: ExpatlioDesign.textStyle(context,
                color: ExpatlioDesign.text, size: 14, weight: FontWeight.w500),
          ),
          if (localEnd == null) ...[
            const SizedBox(height: 12),
            Text(
              localizations.getVariableText(
                ruText: 'Уведомлять меня о новых собеседниках:',
                enText: 'Notify me about available partners for:',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: PassiveSearchDuration.values.map((duration) {
                final label = switch (duration) {
                  PassiveSearchDuration.thirtyMinutes => localizations
                      .getVariableText(ruText: '30 мин', enText: '30 min'),
                  PassiveSearchDuration.sixtyMinutes => localizations
                      .getVariableText(ruText: '60 мин', enText: '60 min'),
                  PassiveSearchDuration.endOfDay =>
                    localizations.getVariableText(
                        ruText: 'Весь день (до 00:00)',
                        enText: 'All day (until midnight)'),
                };
                return OutlinedButton(
                  key: ValueKey('passive-duration-${duration.value}'),
                  onPressed: busy ? null : () => onChoose(duration),
                  child: Text(label),
                );
              }).toList(),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 8),
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: ExpatlioDesign.danger)),
          ],
        ],
      ),
    );
  }
}
