/// 仕様書_データモデルに基づく PlanItem
/// 時刻は ISO 8601。closeTime が無い予定は判定対象外。
class PlanItem {
  PlanItem({
    required this.id,
    required this.name,
    required this.placeId,
    required this.lat,
    required this.lng,
    required this.startTime,
    required this.stayMinutes,
    this.address,
    this.closeTime,
    this.deadline,
  });

  final String id;
  final String name;
  final String placeId;
  final double lat;
  final double lng;
  final String startTime;
  final int stayMinutes;
  final String? address; // Places API の住所
  final String? closeTime;
  final String? deadline;

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      id: json['id'] as String,
      name: json['name'] as String,
      placeId: json['placeId'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      startTime: json['startTime'] as String,
      stayMinutes: json['stayMinutes'] as int,
      address: json['address'] as String?,
      closeTime: json['closeTime'] as String?,
      deadline: json['deadline'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'placeId': placeId,
      'lat': lat,
      'lng': lng,
      'startTime': startTime,
      'stayMinutes': stayMinutes,
      if (address != null) 'address': address,
      if (closeTime != null) 'closeTime': closeTime,
      if (deadline != null) 'deadline': deadline,
    };
  }
}
