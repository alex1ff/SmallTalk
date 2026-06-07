import 'package:flutter/material.dart';

import '/shared_pages/design/expatlio_design.dart';

class ExpatlioSegmentedTabBar extends StatelessWidget {
  const ExpatlioSegmentedTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  static const double height = 38.0;

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    assert(labels.isNotEmpty);
    assert(selectedIndex >= 0 && selectedIndex < labels.length);

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: ExpatlioDesign.mutedSurface,
        borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ExpatlioDesign.space4),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: List.generate(
            labels.length,
            (index) => _SegmentedTabButton(
              label: labels[index],
              selected: selectedIndex == index,
              onTap: () => onChanged(index),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedTabButton extends StatelessWidget {
  const _SegmentedTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: selected ? null : onTap,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: selected ? ExpatlioDesign.card : Colors.transparent,
              borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
              shape: BoxShape.rectangle,
            ),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color:
                      selected ? ExpatlioDesign.text : ExpatlioDesign.inactive,
                  size: 15.0,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
