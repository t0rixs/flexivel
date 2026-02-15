/// 仕様書_API仕様に基づく POST /check の Request
class CheckRequest {
  CheckRequest({
    required this.userId,
    required this.context,
    this.transportMode = 'transit',
  });

  final String userId;
  final CheckRequestContext context;
  final String transportMode;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'context': context.toJson(),
      'transportMode': transportMode,
    };
  }
}

class CheckRequestContext {
  CheckRequestContext({
    required this.now,
    required this.currentLat,
    required this.currentLng,
  });

  final String now; // ISO
  final double currentLat;
  final double currentLng;

  Map<String, dynamic> toJson() {
    return {
      'now': now,
      'currentLat': currentLat,
      'currentLng': currentLng,
    };
  }
}
