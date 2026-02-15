import 'broken_option.dart';

/// 仕様書_データモデルに基づく broken 時の最新状態（Firestore lastBroken）
class LastBroken {
  LastBroken({
    required this.createdAt,
    required this.targetItemId,
    required this.options,
  });

  final String createdAt; // ISO
  final String targetItemId;
  final List<BrokenOption> options;

  factory LastBroken.fromJson(Map<String, dynamic> json) {
    return LastBroken(
      createdAt: json['createdAt'] as String,
      targetItemId: json['targetItemId'] as String,
      options: (json['options'] as List<dynamic>)
          .map((e) => BrokenOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt,
      'targetItemId': targetItemId,
      'options': options.map((e) => e.toJson()).toList(),
    };
  }
}
