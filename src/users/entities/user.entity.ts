/**
 * 仕様書_データモデル §2: Firestore users/{userId} ドキュメントに対応するエンティティ
 *
 * Collection: users
 * Document:   users/{userId}
 */

import { Plan, PlanItem } from '../../types/plan.types.js';
import { LastBroken } from '../../types/broken.types.js';

export type { Plan, PlanItem, LastBroken };

/**
 * Firestore users/{userId} のドキュメント構造
 */
export class UserEntity {
  /** Firestore document ID（= Firebase Auth UID） */
  userId: string;

  /** 現在の旅程（startTime昇順） */
  plan: Plan;

  /** 最新のbroken判定結果（上書き保持） */
  lastBroken?: LastBroken;

  /** 最終更新時刻（ISO 8601） */
  updatedAt: string;
}
