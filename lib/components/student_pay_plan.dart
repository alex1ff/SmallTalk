import 'package:flutter/material.dart';

enum StudentPayPlanKind { trialMonthly, monthly, quarterly }

class StudentPayPlan {
  const StudentPayPlan({
    required this.kind,
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.periodLabel,
    required this.icon,
    required this.features,
    this.badge,
  });

  final StudentPayPlanKind kind;
  final String productId;
  final String title;
  final String subtitle;
  final String periodLabel;
  final IconData icon;
  final List<String> features;
  final String? badge;

  StudentPayPlan copyWith({
    StudentPayPlanKind? kind,
    String? productId,
    String? title,
    String? subtitle,
    String? periodLabel,
    IconData? icon,
    List<String>? features,
    String? badge,
  }) {
    return StudentPayPlan(
      kind: kind ?? this.kind,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      periodLabel: periodLabel ?? this.periodLabel,
      icon: icon ?? this.icon,
      features: features ?? this.features,
      badge: badge ?? this.badge,
    );
  }
}
