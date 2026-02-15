/**
 * 仕様書_データモデル に基づく LastBroken / BrokenOption / DetourCandidate 型定義
 */

export interface DetourCandidate {
  placeId: string;
  name: string;

  lat: number;
  lng: number;
  address: string;

  reason: string;

  startTime: string; // ISO（MVPはAI提案値を信じる）
  stayMinutes: number; // AI提案値
}

export type BrokenOption =
  | {
      kind: 'GO_NEXT';
      reason: string;
    }
  | {
      kind: 'DETOUR';
      reason: string;
      candidates: DetourCandidate[]; // 3件
    }
  | {
      kind: 'SKIP';
      reason: string;
    };

export interface LastBroken {
  createdAt: string; // ISO（broken判定した時刻）
  targetItemId: string; // broken対象の PlanItem.id
  options: BrokenOption[]; // GO_NEXT / DETOUR / SKIP
}
