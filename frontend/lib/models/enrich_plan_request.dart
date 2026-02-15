/// 仕様書_API仕様に基づく POST /enrich-plan の Request（予定入力補完）
class EnrichPlanItemInput {
  EnrichPlanItemInput({
    required this.id,
    required this.name,
    required this.startTime,
    required this.stayMinutes,
    this.placeId,
  });

  final String id;
  final String name;
  final String startTime;
  final int stayMinutes;
  /// オートコンプリートで選択した場合の placeId（指定時は searchText をスキップ）
  final String? placeId;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id,
      'name': name,
      'startTime': startTime,
      'stayMinutes': stayMinutes,
    };
    if (placeId != null && placeId!.isNotEmpty) m['placeId'] = placeId;
    return m;
  }
}

class EnrichPlanRequest {
  EnrichPlanRequest({
    required this.userId,
    required this.plan,
    this.transportMode = 'transit',
  });

  final String userId;
  final EnrichPlanRequestPlan plan;
  final String transportMode;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'plan': plan.toJson(),
      'transportMode': transportMode,
    };
  }
}

class EnrichPlanRequestPlan {
  EnrichPlanRequestPlan({
    required this.planId,
    required this.createdAt,
    required this.items,
  });

  final String planId;
  final String createdAt;
  final List<EnrichPlanItemInput> items;

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'createdAt': createdAt,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
