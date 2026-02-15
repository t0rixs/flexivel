import 'plan.dart';

/// 仕様書_API仕様に基づく POST /enrich-plan の Response
class EnrichPlanResponse {
  EnrichPlanResponse({
    required this.status,
    this.plan,
    this.message,
  });

  final String status; // 'ok' | 'error'
  final Plan? plan;
  final String? message;

  factory EnrichPlanResponse.fromJson(Map<String, dynamic> json) {
    return EnrichPlanResponse(
      status: json['status'] as String,
      plan: json['plan'] != null
          ? Plan.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}
