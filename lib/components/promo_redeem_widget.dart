// PromoRedeemWidget — bottom sheet to redeem a promo code.
//
// Opens from any "У меня есть промокод" CTA. Sends the code to the
// `redeemPromoCode` Cloud Function which validates it and grants gift
// minutes to the user. On success, shows the granted amount + expiry
// and closes the sheet.
//
// Usage:
//   await showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => const PromoRedeemWidget(),
//   );

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/shared_pages/design/expatlio_design.dart';

class PromoRedeemWidget extends StatefulWidget {
  const PromoRedeemWidget({super.key});

  @override
  State<PromoRedeemWidget> createState() => _PromoRedeemWidgetState();
}

class _PromoRedeemWidgetState extends State<PromoRedeemWidget> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  bool _isSubmitting = false;
  String? _errorMessage;
  _SuccessInfo? _success;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(
          () => _errorMessage = FFLocalizations.of(context).getVariableText(
                ruText: 'Введите промокод',
                enText: 'Enter a promo code',
              ));
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('redeemPromoCode');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'code': code,
      });
      final data = result.data;
      final minutes = (data['minutesGifted'] as num?)?.toInt() ?? 0;
      final remaining =
          (data['remainingMinutes'] as num?)?.toDouble() ?? minutes.toDouble();
      final expiresAtMs = (data['expiresAtMs'] as num?)?.toInt();
      final expiresAt = expiresAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
          : null;

      if (!mounted) return;
      setState(() {
        _success = _SuccessInfo(
          minutesGifted: minutes,
          remainingMinutes: remaining,
          expiresAt: expiresAt,
        );
        _isSubmitting = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message ??
            FFLocalizations.of(context).getVariableText(
              ruText: 'Не удалось активировать промокод. Попробуйте позже.',
              enText: "Couldn't redeem the promo code. Try again later.",
            );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось активировать промокод.',
          enText: "Couldn't redeem the promo code.",
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final success = _success;
    return Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: Container(
        decoration: ExpatlioDesign.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(
            ExpatlioDesign.space24,
            ExpatlioDesign.space16,
            ExpatlioDesign.space24,
            ExpatlioDesign.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.alternate,
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusCapsule),
                ),
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space16),
            if (success != null)
              ..._buildSuccess(theme, success)
            else
              ..._buildForm(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildForm(FlutterFlowTheme theme) => [
        Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Введите промокод',
            enText: 'Enter a promo code',
          ),
          textAlign: TextAlign.center,
          style: ExpatlioDesign.bottomSheetTitleStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Промокод добавит подарочные минуты на ваш счёт',
            enText: 'Promo codes top up your gift minutes',
          ),
          textAlign: TextAlign.center,
          style: theme.bodySmall.override(
            fontFamily: theme.bodySmallFamily,
            color: theme.secondaryText,
            letterSpacing: 0.0,
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space24),
        Container(
          decoration: ExpatlioDesign.formGroupDecoration(),
          padding: ExpatlioDesign.formGroupPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Промокод',
                  enText: 'Promo code',
                ),
                style: ExpatlioDesign.formLabelStyle(context),
              ),
              const SizedBox(height: ExpatlioDesign.space8),
              TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textAlignVertical: TextAlignVertical.center,
                enabled: !_isSubmitting,
                decoration: ExpatlioDesign.formFieldDecoration(
                  context,
                  hintText: 'PROMO2026',
                  enabled: !_isSubmitting,
                ).copyWith(errorText: _errorMessage),
                style: ExpatlioDesign.formTextStyle(
                  context,
                  enabled: !_isSubmitting,
                ).copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space16),
        FFButtonWidget(
          onPressed: _isSubmitting ? null : _submit,
          text: _isSubmitting
              ? FFLocalizations.of(context).getVariableText(
                  ruText: 'Активируется…',
                  enText: 'Activating…',
                )
              : FFLocalizations.of(context).getVariableText(
                  ruText: 'Активировать',
                  enText: 'Redeem',
                ),
          options: FFButtonOptions(
            height: ExpatlioDesign.buttonHeight,
            color: theme.primary,
            textStyle: theme.titleSmall.override(
              fontFamily: theme.titleSmallFamily,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.0,
            ),
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
            elevation: 0,
          ),
        ),
      ];

  List<Widget> _buildSuccess(FlutterFlowTheme theme, _SuccessInfo info) => [
        Icon(
          Icons.celebration_rounded,
          size: 56,
          color: theme.primary,
        ),
        const SizedBox(height: ExpatlioDesign.space12),
        Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Промокод активирован',
            enText: 'Promo code redeemed',
          ),
          textAlign: TextAlign.center,
          style: ExpatlioDesign.bottomSheetTitleStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Text(
          _buildSuccessMessage(info),
          textAlign: TextAlign.center,
          style: theme.bodyMedium.override(
            fontFamily: theme.bodyMediumFamily,
            color: theme.secondaryText,
            letterSpacing: 0.0,
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space24),
        FFButtonWidget(
          onPressed: () => Navigator.pop(context),
          text: FFLocalizations.of(context).getVariableText(
            ruText: 'Готово',
            enText: 'Done',
          ),
          options: FFButtonOptions(
            height: ExpatlioDesign.buttonHeight,
            color: theme.primary,
            textStyle: theme.titleSmall.override(
              fontFamily: theme.titleSmallFamily,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.0,
            ),
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
            elevation: 0,
          ),
        ),
      ];

  String _buildSuccessMessage(_SuccessInfo info) {
    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    final m = info.minutesGifted;
    final total = info.remainingMinutes.toStringAsFixed(0);
    final expiryLine = info.expiresAt != null
        ? '\n${isRu ? 'Действует до' : 'Valid until'} ${_formatExpiry(info.expiresAt!)}'
        : '';
    if (isRu) {
      return '+$m мин подарка\nВсего доступно: $total мин$expiryLine';
    }
    return '+$m gift minutes\nTotal available: $total min$expiryLine';
  }

  String _formatExpiry(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m в $h:$min';
  }
}

class _SuccessInfo {
  _SuccessInfo({
    required this.minutesGifted,
    required this.remainingMinutes,
    required this.expiresAt,
  });

  final int minutesGifted;
  final double remainingMinutes;
  final DateTime? expiresAt;
}
