/**
 * 仕様書_API仕様 に基づく POST /apply-option の Request / Response 型
 */

import { Plan } from './plan.types';

export type ApplyOptionChoice =
  | { kind: 'GO_NEXT' }
  | { kind: 'SKIP' }
  | { kind: 'DETOUR'; detourPlaceId: string };

export interface ApplyOptionRequest {
  userId: string;
  targetItemId: string; // /checkで返された broken 対象
  choice: ApplyOptionChoice;
  transportMode: 'transit';
}

export interface ApplyOptionResponse {
  status: 'ok' | 'error';
  updatedPlan?: Plan;
  message?: string;
}
