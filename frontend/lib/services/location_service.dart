import 'package:geolocator/geolocator.dart';

/// 位置情報の取得（§5.1: 15分おきに位置を取得）
class LocationService {
  /// 位置情報の権限チェック＆取得
  Future<Position> getCurrentPosition() async {
    // 位置情報サービスが有効か
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('位置情報サービスが無効です。');
    }

    // 権限チェック
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('位置情報の権限が拒否されました。');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException('位置情報の権限が永久に拒否されています。設定から有効にしてください。');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}

class LocationException implements Exception {
  LocationException(this.message);
  final String message;

  @override
  String toString() => 'LocationException: $message';
}
