/// 仕様書_API仕様に基づく POST /apply-option の Request
/// choice: GO_NEXT / SKIP / DETOUR(detourPlaceId)
sealed class ApplyOptionChoice {
  const ApplyOptionChoice();
  Map<String, dynamic> toJson();
}

class ApplyOptionChoiceGoNext extends ApplyOptionChoice {
  const ApplyOptionChoiceGoNext();
  @override
  Map<String, dynamic> toJson() => {'kind': 'GO_NEXT'};
}

class ApplyOptionChoiceSkip extends ApplyOptionChoice {
  const ApplyOptionChoiceSkip();
  @override
  Map<String, dynamic> toJson() => {'kind': 'SKIP'};
}

class ApplyOptionChoiceDetour extends ApplyOptionChoice {
  ApplyOptionChoiceDetour({required this.detourPlaceId});
  final String detourPlaceId;
  @override
  Map<String, dynamic> toJson() =>
      {'kind': 'DETOUR', 'detourPlaceId': detourPlaceId};
}

class ApplyOptionRequest {
  ApplyOptionRequest({
    required this.userId,
    required this.targetItemId,
    required this.choice,
    this.transportMode = 'transit',
  });

  final String userId;
  final String targetItemId;
  final ApplyOptionChoice choice;
  final String transportMode;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'targetItemId': targetItemId,
      'choice': choice.toJson(),
      'transportMode': transportMode,
    };
  }
}
