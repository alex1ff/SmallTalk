import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

enum AppLoadingIndicatorSize { medium }

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = AppLoadingIndicatorSize.medium,
  });

  final AppLoadingIndicatorSize size;

  double get _dimension {
    return switch (size) {
      AppLoadingIndicatorSize.medium => 50.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _dimension,
      height: _dimension,
      child: SpinKitCircle(
        color: ExpatlioDesign.primary,
        size: _dimension,
      ),
    );
  }
}
