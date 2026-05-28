import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '/shared_pages/design/expatlio_design.dart';

class NativeSpeakerEntryToggle extends StatelessWidget {
  const NativeSpeakerEntryToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ExpatlioDesign.formFieldHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Войти как Native Speaker',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.formTextStyle(context).copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          AdaptiveSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: ExpatlioDesign.success,
          ),
        ],
      ),
    );
  }
}
