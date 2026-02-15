/// Places API オートコンプリートの候補1件
class PlaceAutocompletePrediction {
  PlaceAutocompletePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  factory PlaceAutocompletePrediction.fromJson(Map<String, dynamic> json) {
    return PlaceAutocompletePrediction(
      placeId: json['placeId'] as String? ?? '',
      mainText: json['mainText'] as String? ?? '',
      secondaryText: json['secondaryText'] as String? ?? '',
      fullText: json['fullText'] as String? ?? '',
    );
  }
}
