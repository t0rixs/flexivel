/**
 * 仕様書_API仕様 に基づく POST /enrich-plan の Request / Response 型
 */

import { Plan } from './plan.types';

export interface EnrichPlanItemInput {
  id: string;
  name: string; // ユーザー入力
  startTime: string; // ユーザー入力
  stayMinutes: number; // ユーザー入力
  // placeId/latlng/closeTime/deadlineは未入力でもよい
}

export interface EnrichPlanRequest {
  userId: string;
  plan: {
    planId: string;
    createdAt: string;
    items: EnrichPlanItemInput[];
  };
  transportMode: 'transit';
}

export interface EnrichPlanResponse {
  status: 'ok' | 'error';
  plan?: Plan; // placeId/latlng/closeTime/deadline を埋めたPlan
  message?: string;
}
