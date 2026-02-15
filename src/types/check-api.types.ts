/**
 * 仕様書_API仕様 に基づく POST /check の Request / Response 型
 */

import { BrokenOption } from './broken.types';

export type TransportMode = 'transit';

export interface CheckRequest {
  userId: string;
  context: {
    now: string; // ISO
    currentLat: number;
    currentLng: number;
  };
  transportMode: TransportMode;
}

export interface CheckResponse {
  status: 'ok' | 'warn' | 'broken';

  // warn/brokenの対象（最も危険な1件）
  targetItemId?: string;

  // warn用（端末で通知文生成）
  minutesToDeadline?: number; // 切り捨て整数

  // broken用
  options?: BrokenOption[];
}
