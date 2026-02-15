/**
 * 仕様書_ロジック §5: /check 判定アルゴリズム
 *
 * plan.items から最も危険な1件を選び ok/warn/broken を返す。
 * broken時は BrokenOptionsService で options を生成する。
 */

import { Injectable } from '@nestjs/common';
import type { PlanItem } from '../../types/plan.types.js';
import type { CheckResponse } from '../../types/check-api.types.js';
import type { BrokenOption } from '../../types/broken.types.js';
import { haversineDistance } from '../utils/distance.js';
import { BrokenOptionsService } from './broken-options.service.js';

/** §5.2 候補1件の内部構造 */
interface CheckCandidate {
  itemId: string;
  minutesToDeadline: number;
  withinPrev400m: boolean;
  index: number;
}

/** 400m 閾値（§4） */
const PREV_DISTANCE_THRESHOLD_M = 400;

/** warn の上限分（§5.4: 1 <= m <= 15） */
const WARN_MAX_MINUTES = 15;

@Injectable()
export class CheckService {
  constructor(
    private readonly brokenOptionsService: BrokenOptionsService,
  ) {}

  /**
   * §5 メインロジック
   *
   * @param items     plan.items（startTime昇順）
   * @param now       現在時刻（ISO → Date）
   * @param currentLat 端末の緯度
   * @param currentLng 端末の経度
   * @returns CheckResponse（ok / warn / broken）
   */
  async check(
    items: PlanItem[],
    now: Date,
    currentLat: number,
    currentLng: number,
  ): Promise<CheckResponse> {
    const n = items.length;

    // §5.1 監視対象の有無 — n < 3 なら常に ok
    if (n < 3) {
      return { status: 'ok' };
    }

    // §5.2 candidates 生成（i = 1 .. n-2）
    const candidates: CheckCandidate[] = [];

    for (let i = 1; i <= n - 2; i++) {
      const item = items[i];

      // §3 判定に必要なフィールドが揃っているか
      if (!item.deadline || !item.closeTime) {
        continue;
      }

      const deadlineMs = new Date(item.deadline).getTime();
      const nowMs = now.getTime();
      const m = Math.floor((deadlineMs - nowMs) / 60_000); // 切り捨て整数

      // §4 prev との距離判定
      const prev = items[i - 1];
      const d = haversineDistance(
        currentLat,
        currentLng,
        prev.lat,
        prev.lng,
      );

      candidates.push({
        itemId: item.id,
        minutesToDeadline: m,
        withinPrev400m: d <= PREV_DISTANCE_THRESHOLD_M,
        index: i,
      });
    }

    // §5.3 target 選定 — candidates が空なら ok
    if (candidates.length === 0) {
      return { status: 'ok' };
    }

    // 最も minutesToDeadline が小さい（締切が近い）1件
    const target = candidates.reduce((min, c) =>
      c.minutesToDeadline < min.minutesToDeadline ? c : min,
    );

    // §5.4 ok / warn / broken の判定
    if (!target.withinPrev400m) {
      return { status: 'ok' };
    }

    const m = target.minutesToDeadline;

    // broken: m <= 0
    if (m <= 0) {
      const options: BrokenOption[] =
        await this.brokenOptionsService.generateOptions(
          items,
          target.index,
          now,
          currentLat,
          currentLng,
        );
      return {
        status: 'broken',
        targetItemId: target.itemId,
        options,
      };
    }

    // warn: 1 <= m <= 15
    if (m >= 1 && m <= WARN_MAX_MINUTES) {
      return {
        status: 'warn',
        targetItemId: target.itemId,
        minutesToDeadline: m,
      };
    }

    // それ以外は ok
    return { status: 'ok' };
  }
}
