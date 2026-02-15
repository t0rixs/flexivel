/**
 * 仕様書_データモデル に基づく Plan / PlanItem 型定義
 * 時刻は ISO 8601 文字列。items は startTime 昇順が前提。
 */

export interface PlanItem {
  id: string; // UUID想定（placeIdで代用しない）
  name: string; // 表示名（Places API 取得時は正式名称、未取得時はユーザー入力）

  placeId: string; // Google Places place_id
  lat: number;
  lng: number;
  address?: string; // Places API の住所（一覧表示用）

  startTime: string; // 到着予定時刻（ISO）
  stayMinutes: number; // ユーザー手入力

  closeTime?: string; // ISO（取れない場合は未設定→判定対象外）
  deadline?: string; // ISO（入力時に逆算して保存）
}

export interface Plan {
  planId: string; // UUID想定
  createdAt: string; // ISO
  items: PlanItem[]; // startTime昇順
}
