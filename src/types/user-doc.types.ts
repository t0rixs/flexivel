/**
 * 仕様書_データモデル に基づく Firestore users/{userId} ドキュメント型
 */

import { Plan } from './plan.types';
import { LastBroken } from './broken.types';

export interface UserDoc {
  plan: Plan;
  lastBroken?: LastBroken; // 最新のみ上書き
  updatedAt: string; // ISO
}
