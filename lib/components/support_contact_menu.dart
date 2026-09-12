import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

const ValueKey<String> supportContactMenuKey =
    ValueKey<String>('support_contact_menu');

class SupportContactMenu extends StatelessWidget {
  const SupportContactMenu({
    super.key,
    required this.email,
    required this.telegram,
    required this.onEmailTap,
    required this.onTelegramTap,
    this.emailFocusNode,
  });

  final String email;
  final String telegram;
  final VoidCallback onEmailTap;
  final VoidCallback onTelegramTap;
  final FocusNode? emailFocusNode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space16,
            ExpatlioDesign.space16,
            ExpatlioDesign.space16,
            ExpatlioDesign.space16),
        decoration: BoxDecoration(
          color: ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
          border: Border.all(color: ExpatlioDesign.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24.0,
              offset: Offset(0.0, 10.0),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Свяжитесь с нашей командой удобным способом',
                enText: 'Contact our team using a convenient method',
              ),
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 13.0,
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space12),
            _SupportContactCard(
              icon: Icons.mail_outline_rounded,
              title: 'Email',
              value: email,
              onTap: onEmailTap,
              focusNode: emailFocusNode,
              autofocus: emailFocusNode != null,
            ),
            const SizedBox(height: ExpatlioDesign.space8),
            _SupportContactCard(
              icon: Icons.near_me_outlined,
              title: 'Telegram',
              value: telegram,
              onTap: onTelegramTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportContactCard extends StatelessWidget {
  const _SupportContactCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.focusNode,
    this.autofocus = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusNode: focusNode,
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space12,
            ExpatlioDesign.space12,
            ExpatlioDesign.space12,
            ExpatlioDesign.space12),
        decoration: BoxDecoration(
          color: ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
          border: Border.all(color: ExpatlioDesign.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36.0,
              height: 36.0,
              decoration: ExpatlioDesign.softPrimaryDecoration(radius: 11.0),
              child: Icon(
                icon,
                color: ExpatlioDesign.primary,
                size: 20.0,
              ),
            ),
            const SizedBox(width: ExpatlioDesign.space12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ExpatlioDesign.textStyle(
                      context,
                      color: ExpatlioDesign.muted,
                      size: 13.0,
                    ),
                  ),
                  const SizedBox(height: ExpatlioDesign.space4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 15.0,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
