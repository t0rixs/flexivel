/**
 * 仕様書（アーキテクチャ・データモデル・API仕様）に基づくデータ構造のエクスポート
 */

// Firestore / ドメイン
export type { Plan, PlanItem } from './plan.types.js';
export type { LastBroken, BrokenOption, DetourCandidate } from './broken.types.js';
export type { UserDoc } from './user-doc.types.js';

// POST /check
export type { CheckRequest, CheckResponse, TransportMode } from './check-api.types.js';

// POST /apply-option
export type {
  ApplyOptionRequest,
  ApplyOptionResponse,
  ApplyOptionChoice,
} from './apply-option-api.types.js';

// POST /enrich-plan
export type {
  EnrichPlanRequest,
  EnrichPlanResponse,
  EnrichPlanItemInput,
} from './enrich-plan-api.types.js';
