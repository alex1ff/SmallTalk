// PromoRedeemWidget — bottom sheet to redeem a promo code.
//
// Opens from any "У меня есть промокод" CTA. Sends the code to the
// `redeemPromoCode` Cloud Function which validates it and grants gift
// minutes to the user. On success, shows the granted amount + expiry
// and closes the sheet.
//
// Usage:
//   await showPromoRedeemSheet(context: context);

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '/components/bottom_sheet_header.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/utils/subscription_utils.dart';

typedef PromoRedeemOverride = Future<Map<dynamic, dynamic>> Function(
  String code,
);

Future<bool?> showPromoRedeemSheet({
  required BuildContext context,
  PromoRedeemOverride? redeemOverride,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => PromoRedeemWidget(redeemOverride: redeemOverride),
  );
}

class PromoRedeemWidget extends StatefulWidget {
  const PromoRedeemWidget({
    super.key,
    this.redeemOverride,
  });

  final PromoRedeemOverride? redeemOverride;

  @override
  State<PromoRedeemWidget> createState() => _PromoRedeemWidgetState();
}

class _PromoRedeemWidgetState extends State<PromoRedeemWidget> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  bool _isSubmitting = false;
  bool _isFinishing = false;
  bool _allowSuccessPop = false;
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
      final override = widget.redeemOverride;
      final Map<dynamic, dynamic> data;
      if (override != null) {
        data = await override(code);
      } else {
        final callable =
            FirebaseFunctions.instance.httpsCallable('redeemPromoCode');
        final result = await callable.call<Map<dynamic, dynamic>>({
          'code': code,
        });
        data = result.data;
      }
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
        _errorMessage = _localizedPromoError(e.code);
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

  String _localizedPromoError(String code) {
    final localization = FFLocalizations.of(context);
    switch (code) {
      case 'unauthenticated':
        return localization.getVariableText(
          ruText: 'Войдите в аккаунт и попробуйте снова.',
          enText: 'Sign in and try again.',
        );
      case 'invalid-argument':
        return localization.getVariableText(
          ruText: 'Проверьте промокод и попробуйте снова.',
          enText: 'Check the promo code and try again.',
        );
      case 'not-found':
        return localization.getVariableText(
          ruText: 'Промокод не найден.',
          enText: 'Promo code not found.',
        );
      case 'already-exists':
        return localization.getVariableText(
          ruText: 'Этот промокод уже активирован.',
          enText: 'This promo code has already been redeemed.',
        );
      case 'failed-precondition':
        return localization.getVariableText(
          ruText: 'Промокод истёк или больше недоступен.',
          enText: 'This promo code has expired or is no longer available.',
        );
      default:
        return localization.getVariableText(
          ruText: 'Не удалось активировать промокод. Попробуйте позже.',
          enText: "Couldn't redeem the promo code. Try again later.",
        );
    }
  }

  void _finishSuccess() {
    if (!mounted || _isFinishing || _success == null) {
      return;
    }
    _isFinishing = true;
    setState(() => _allowSuccessPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final success = _success;
    return PopScope<Object?>(
      canPop: (!_isSubmitting && success == null) || _allowSuccessPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && success != null) {
          _finishSuccess();
        }
      },
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: MediaQuery.viewInsetsOf(context),
          child: Container(
            decoration: ExpatlioDesign.sheetDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BottomSheetHeader(
                  title: success != null
                      ? FFLocalizations.of(context).getVariableText(
                          ruText: 'Промокод активирован',
                          enText: 'Promo code redeemed',
                        )
                      : FFLocalizations.of(context).getVariableText(
                          ruText: 'Введите промокод',
                          enText: 'Enter a promo code',
                        ),
                ),
                const SizedBox(height: ExpatlioDesign.space16),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space24,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space24,
                    ExpatlioDesign.space24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: success != null
                        ? _buildSuccess(theme, success)
                        : _buildForm(theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildForm(FlutterFlowTheme theme) => [
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
        const SizedBox(height: ExpatlioDesign.space8),
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Отмена',
              enText: 'Cancel',
            ),
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
          onPressed: _finishSuccess,
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
        ? '\n${isRu ? 'Действует до' : 'Valid until'} ${formatGiftExpiry(
            info.expiresAt,
            languageCode: isRu ? 'ru' : 'en',
          )}'
        : '';
    if (isRu) {
      return '+$m мин подарка\nВсего доступно: $total мин$expiryLine';
    }
    return '+$m gift minutes\nTotal available: $total min$expiryLine';
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
