import 'dart:math' as math;

import '/backend/backend.dart';
import '/components/retained_payment_stream_builder.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

enum TeacherPayoutCardsState { loading, error, loaded }

enum TeacherPayoutCardsRefreshState { idle, refreshing, error }

const double teacherPayoutCardRowHeight = 60.0;
const double teacherPayoutCardLeadingSize = 52.0;
const double teacherPayoutCardActionSize = 30.0;

const teacherPayoutCardsSectionKey =
    ValueKey<String>('teacher_payout_cards_section');
const teacherPayoutCardsHeaderKey =
    ValueKey<String>('teacher_payout_cards_header');
const teacherPayoutCardsEditSlotKey =
    ValueKey<String>('teacher_payout_cards_edit_slot');
const teacherPayoutCardsRowsSlotKey =
    ValueKey<String>('teacher_payout_cards_rows_slot');
const teacherPayoutCardLoadingKey =
    ValueKey<String>('teacher_payout_card_loading');
const teacherPayoutCardErrorKey = ValueKey<String>('teacher_payout_card_error');
const teacherPayoutCardsRetryButtonKey =
    ValueKey<String>('teacher_payout_cards_retry');
const teacherPayoutCardsRefreshingKey =
    ValueKey<String>('teacher_payout_cards_refreshing');

ValueKey<String> teacherPayoutCardRowKey(int slot) =>
    ValueKey<String>('teacher_payout_card_row_$slot');

ValueKey<String> teacherPayoutCardLeadingSlotKey(int slot) =>
    ValueKey<String>('teacher_payout_card_leading_slot_$slot');

ValueKey<String> teacherPayoutCardTextSlotKey(int slot) =>
    ValueKey<String>('teacher_payout_card_text_slot_$slot');

ValueKey<String> teacherPayoutCardActionSlotKey(int slot) =>
    ValueKey<String>('teacher_payout_card_action_slot_$slot');

ValueKey<String> teacherPayoutCardSelectedIndicatorKey(int slot) =>
    ValueKey<String>('teacher_payout_card_selected_indicator_$slot');

class TeacherPayoutCardItem {
  const TeacherPayoutCardItem({
    required this.pan,
    required this.selected,
    required this.onTap,
  });

  final String pan;
  final bool selected;
  final VoidCallback onTap;
}

DocumentReference? resolveTeacherPayoutSelectedCard({
  required List<CardsRecord> cards,
  required DocumentReference? selectedCard,
  required bool shouldAutoSelectFirstCard,
}) {
  if (cards.isEmpty) {
    return null;
  }
  if (selectedCard != null) {
    final stillAvailable = cards.any(
      (card) => card.reference.path == selectedCard.path,
    );
    return stillAvailable ? selectedCard : cards.first.reference;
  }
  return shouldAutoSelectFirstCard ? cards.first.reference : null;
}

class TeacherPayoutCardsStreamSection extends StatelessWidget {
  const TeacherPayoutCardsStreamSection({
    super.key,
    required this.ownerKey,
    required this.stream,
    required this.selectedCard,
    required this.shouldAutoSelectFirstCard,
    required this.onCardsChanged,
    required this.onCardTap,
    required this.onEditPressed,
    this.onRetry,
  });

  final String ownerKey;
  final Stream<List<CardsRecord>> stream;
  final DocumentReference? selectedCard;
  final bool shouldAutoSelectFirstCard;
  final ValueChanged<List<CardsRecord>> onCardsChanged;
  final ValueChanged<DocumentReference> onCardTap;
  final VoidCallback onEditPressed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return RetainedPaymentStreamBuilder<CardsRecord>(
      ownerKey: ownerKey,
      stream: stream,
      builder: (context, view) {
        onCardsChanged(view.data);
        final effectiveSelectedCard = resolveTeacherPayoutSelectedCard(
          cards: view.data,
          selectedCard: selectedCard,
          shouldAutoSelectFirstCard: shouldAutoSelectFirstCard,
        );
        final state = switch (view.phase) {
          RetainedPaymentStreamPhase.initialLoading =>
            TeacherPayoutCardsState.loading,
          RetainedPaymentStreamPhase.errorWithoutData =>
            TeacherPayoutCardsState.error,
          _ => TeacherPayoutCardsState.loaded,
        };
        final refreshState = switch (view.phase) {
          RetainedPaymentStreamPhase.refreshing =>
            TeacherPayoutCardsRefreshState.refreshing,
          RetainedPaymentStreamPhase.errorWithData ||
          RetainedPaymentStreamPhase.errorWithoutData =>
            TeacherPayoutCardsRefreshState.error,
          _ => TeacherPayoutCardsRefreshState.idle,
        };

        return TeacherPayoutCardsSection(
          state: state,
          items: [
            for (final card in view.data)
              TeacherPayoutCardItem(
                pan: card.pan,
                selected: card.reference.path == effectiveSelectedCard?.path,
                onTap: () => onCardTap(card.reference),
              ),
          ],
          onEditPressed: view.data.isEmpty ? null : onEditPressed,
          refreshState: refreshState,
          onRetry: onRetry,
        );
      },
    );
  }
}

class TeacherPayoutCardsSection extends StatelessWidget {
  const TeacherPayoutCardsSection({
    super.key,
    required this.state,
    required this.items,
    required this.onEditPressed,
    this.refreshState = TeacherPayoutCardsRefreshState.idle,
    this.onRetry,
  });

  final TeacherPayoutCardsState state;
  final List<TeacherPayoutCardItem> items;
  final VoidCallback? onEditPressed;
  final TeacherPayoutCardsRefreshState refreshState;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final headerHeight = math.max(
      48.0,
      MediaQuery.textScalerOf(context).scale(20.0) * 1.2,
    );
    final rows = switch (state) {
      TeacherPayoutCardsState.loading => const [
          _TeacherPayoutCardRow(
            slot: 0,
            state: _TeacherPayoutCardRowState.loading,
          ),
        ],
      TeacherPayoutCardsState.error => const [
          _TeacherPayoutCardRow(
            slot: 0,
            state: _TeacherPayoutCardRowState.error,
          ),
        ],
      TeacherPayoutCardsState.loaded when items.isEmpty => const [
          _TeacherPayoutCardRow(
            slot: 0,
            state: _TeacherPayoutCardRowState.empty,
          ),
        ],
      TeacherPayoutCardsState.loaded => [
          for (var index = 0; index < items.length; index++)
            _TeacherPayoutCardRow(
              slot: index,
              state: _TeacherPayoutCardRowState.data,
              item: items[index],
            ),
        ],
    };

    return Container(
      key: teacherPayoutCardsSectionKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            key: teacherPayoutCardsHeaderKey,
            height: headerHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    FFLocalizations.of(context).getText(
                      'j9s3fbnb' /* Выберите способ вывода */,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Cool',
                          fontSize: 20.0,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                SizedBox(
                  key: teacherPayoutCardsEditSlotKey,
                  width: 48.0,
                  height: 48.0,
                  child: switch (refreshState) {
                    TeacherPayoutCardsRefreshState.refreshing => Center(
                        child: SizedBox(
                          key: teacherPayoutCardsRefreshingKey,
                          width: 20.0,
                          height: 20.0,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                    TeacherPayoutCardsRefreshState.error => Semantics(
                        key: teacherPayoutCardsRetryButtonKey,
                        container: true,
                        button: true,
                        label: FFLocalizations.of(context).getVariableText(
                          ruText: 'Повторить загрузку карт',
                          enText: 'Retry loading cards',
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              ExpatlioDesign.radiusMedium,
                            ),
                            onTap: onRetry,
                            child: Center(
                              child: Container(
                                width: 40.0,
                                height: 40.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusMedium,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.refresh_rounded,
                                  color: FlutterFlowTheme.of(context).error,
                                  size: 20.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    TeacherPayoutCardsRefreshState.idle => IgnorePointer(
                        ignoring: onEditPressed == null,
                        child: Opacity(
                          opacity: onEditPressed == null ? 0.0 : 1.0,
                          child: Center(
                            child: FlutterFlowIconButton(
                              borderRadius: ExpatlioDesign.radiusMedium,
                              buttonSize: 40.0,
                              fillColor: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              icon: Icon(
                                FFIcons.kedit05,
                                color: FlutterFlowTheme.of(context).primaryText,
                                size: 18.0,
                              ),
                              onPressed: onEditPressed ?? () {},
                            ),
                          ),
                        ),
                      ),
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: ExpatlioDesign.space8),
          Column(
            key: teacherPayoutCardsRowsSlotKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                rows[index],
                if (index != rows.length - 1)
                  const SizedBox(height: ExpatlioDesign.space8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

enum _TeacherPayoutCardRowState { loading, error, empty, data }

class _TeacherPayoutCardRow extends StatelessWidget {
  const _TeacherPayoutCardRow({
    required this.slot,
    required this.state,
    this.item,
  });

  final int slot;
  final _TeacherPayoutCardRowState state;
  final TeacherPayoutCardItem? item;

  @override
  Widget build(BuildContext context) {
    final isData = state == _TeacherPayoutCardRowState.data;
    final label = switch (state) {
      _TeacherPayoutCardRowState.loading =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Загрузка карт',
          enText: 'Loading cards',
        ),
      _TeacherPayoutCardRowState.error =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось загрузить карты',
          enText: 'Could not load cards',
        ),
      _TeacherPayoutCardRowState.empty =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Нет сохранённых карт',
          enText: 'No saved cards',
        ),
      _TeacherPayoutCardRowState.data => item!.pan,
    };

    return InkWell(
      onTap: isData ? item!.onTap : null,
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
      child: Container(
        key: teacherPayoutCardRowKey(slot),
        width: double.infinity,
        height: teacherPayoutCardRowHeight,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
          border: Border.all(
            color: isData ? Colors.transparent : ExpatlioDesign.border,
          ),
        ),
        padding: const EdgeInsets.all(ExpatlioDesign.space4),
        child: Row(
          children: [
            Container(
              key: teacherPayoutCardLeadingSlotKey(slot),
              width: teacherPayoutCardLeadingSize,
              height: teacherPayoutCardLeadingSize,
              decoration: BoxDecoration(
                color: ExpatlioDesign.mutedSurface,
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
              ),
              alignment: Alignment.center,
              child: switch (state) {
                _TeacherPayoutCardRowState.loading => const SizedBox(
                    key: teacherPayoutCardLoadingKey,
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
                _TeacherPayoutCardRowState.error => Icon(
                    Icons.error_outline_rounded,
                    key: teacherPayoutCardErrorKey,
                    color: FlutterFlowTheme.of(context).error,
                    size: 20.0,
                  ),
                _ => Icon(
                    FFIcons.kcreditCard02,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 20.0,
                  ),
              },
            ),
            Expanded(
              child: Padding(
                key: teacherPayoutCardTextSlotKey(slot),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space8,
                  ExpatlioDesign.space0,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        color: state == _TeacherPayoutCardRowState.error
                            ? FlutterFlowTheme.of(context).error
                            : FlutterFlowTheme.of(context).primaryText,
                        fontSize: 16.0,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: ExpatlioDesign.space8,
              ),
              child: SizedBox(
                key: teacherPayoutCardActionSlotKey(slot),
                width: teacherPayoutCardActionSize,
                height: teacherPayoutCardActionSize,
                child: item?.selected ?? false
                    ? Container(
                        key: teacherPayoutCardSelectedIndicatorKey(slot),
                        decoration: const BoxDecoration(
                          color: ExpatlioDesign.success,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          FFIcons.kcheck,
                          color: Colors.black,
                          size: 15.0,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
