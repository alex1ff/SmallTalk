import 'package:flutter/material.dart';

enum StudentPayPlanKind { monthly, quarterly }

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
}
