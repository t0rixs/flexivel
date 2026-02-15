/// 仕様書_データモデルに基づく DETOUR 候補1件
/// 座標と住所を必須にして「どの場所か分からない」問題を避ける。
class DetourCandidate {
  DetourCandidate({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.address,
    required this.reason,
    required this.startTime,
    required this.stayMinutes,
  });

  final String placeId;
  final String name;
  final double lat;
  final double lng;
  final String address;
  final String reason;
  final String startTime; // ISO
  final int stayMinutes;

  factory DetourCandidate.fromJson(Map<String, dynamic> json) {
    return DetourCandidate(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String,
      reason: json['reason'] as String,
      startTime: json['startTime'] as String,
      stayMinutes: json['stayMinutes'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'lat': lat,
      'lng': lng,
      'address': address,
      'reason': reason,
      'startTime': startTime,
      'stayMinutes': stayMinutes,
    };
  }
}
