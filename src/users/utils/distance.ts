/**
 * Haversine 式で2点間の距離（メートル）を算出する。
 * 仕様書_ロジック §4「動いていない」判定（400m閾値）で使用。
 */

const EARTH_RADIUS_M = 6_371_000; // 地球半径（メートル）

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}

/**
 * @returns 2点間の距離（メートル）
 */
export function haversineDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return EARTH_RADIUS_M * c;
}
