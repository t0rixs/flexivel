import 'plan.dart';

/// 仕様書_API仕様に基づく POST /apply-option の Response
class ApplyOptionResponse {
  ApplyOptionResponse({
    required this.status,
    this.updatedPlan,
    this.message,
  });

  final String status; // 'ok' | 'error'
  final Plan? updatedPlan;
  final String? message;

  factory ApplyOptionResponse.fromJson(Map<String, dynamic> json) {
    return ApplyOptionResponse(
      status: json['status'] as String,
      updatedPlan: json['updatedPlan'] != null
          ? Plan.fromJson(json['updatedPlan'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}
