import 'plan_item.dart';

/// 仕様書_データモデルに基づく Plan
/// items は startTime 昇順が前提。
class Plan {
  Plan({
    required this.planId,
    required this.createdAt,
    required this.items,
  });

  final String planId;
  final String createdAt;
  final List<PlanItem> items;

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      planId: json['planId'] as String,
      createdAt: json['createdAt'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'createdAt': createdAt,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
