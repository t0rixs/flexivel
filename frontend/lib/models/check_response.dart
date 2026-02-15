import 'broken_option.dart';

/// 仕様書_API仕様に基づく POST /check の Response
class CheckResponse {
  CheckResponse({
    required this.status,
    this.targetItemId,
    this.minutesToDeadline,
    this.options,
  });

  final String status; // 'ok' | 'warn' | 'broken'
  final String? targetItemId;
  final int? minutesToDeadline; // warn用（切り捨て整数）
  final List<BrokenOption>? options; // broken用

  factory CheckResponse.fromJson(Map<String, dynamic> json) {
    return CheckResponse(
      status: json['status'] as String,
      targetItemId: json['targetItemId'] as String?,
      minutesToDeadline: json['minutesToDeadline'] as int?,
      options: json['options'] != null
          ? (json['options'] as List<dynamic>)
              .map((e) => BrokenOption.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
}
