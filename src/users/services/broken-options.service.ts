/**
 * 仕様書_ロジック §8: broken時 options 生成（MVP）
 *
 * GO_NEXT / SKIP は固定文。
 * DETOUR は Places API → Gemini で候補3件を生成する。
 * MVPでは成立保証（次予定に間に合うか検証）は行わない。
 */

import { Injectable, Logger } from '@nestjs/common';
import type { PlanItem } from '../../types/plan.types.js';
import type { BrokenOption, DetourCandidate } from '../../types/broken.types.js';
import { PlacesService } from '../../google/places.service.js';
import { GeminiService } from '../../google/gemini.service.js';

@Injectable()
export class BrokenOptionsService {
  private readonly logger = new Logger(BrokenOptionsService.name);

  constructor(
    private readonly placesService: PlacesService,
    private readonly geminiService: GeminiService,
  ) {}

  /**
   * broken 対象の PlanItem に対して3択（GO_NEXT / DETOUR / SKIP）を生成する。
   */
  async generateOptions(
    items: PlanItem[],
    targetIndex: number,
    now: Date,
    currentLat: number,
    currentLng: number,
  ): Promise<BrokenOption[]> {
    const options: BrokenOption[] = [];

    // ── §8.1 GO_NEXT（固定文） ──
    options.push({
      kind: 'GO_NEXT',
      reason: '次の予定を優先して、すぐ移動します。',
    });

    // ── §8.2 DETOUR（寄り道候補3件） ──
    try {
      const candidates = await this.generateDetourCandidates(
        items,
        targetIndex,
        now,
        currentLat,
        currentLng,
      );

      // 候補が0件の場合は DETOUR を含めない（仕様 §6 例外方針）
      if (candidates.length > 0) {
        options.push({
          kind: 'DETOUR',
          reason: '次の予定に間に合う範囲で寄り道候補を提案します。',
          candidates,
        });
      }
    } catch (err) {
      // DETOUR生成失敗時は GO_NEXT / SKIP のみ（仕様許容）
      this.logger.warn('DETOUR候補の生成に失敗しました', err);
    }

    // ── §8.1 SKIP（固定文） ──
    options.push({
      kind: 'SKIP',
      reason: 'この予定は諦めて、次の予定に備えます。',
    });

    return options;
  }

  /**
   * §8.2 手順:
   *   1. 検索範囲決定（現在地周辺 1km）
   *   2. Places API で candidatePool 取得
   *   3. Gemini に候補集合 + コンテキストを渡す
   *   4. DetourCandidate[3] を返す
   */
  private async generateDetourCandidates(
    items: PlanItem[],
    targetIndex: number,
    now: Date,
    currentLat: number,
    currentLng: number,
  ): Promise<DetourCandidate[]> {
    const targetItem = items[targetIndex];

    // 次の予定（存在すれば）
    const nextItem =
      targetIndex + 1 < items.length ? items[targetIndex + 1] : undefined;

    // Step 1 — 検索範囲: 現在地周辺 1km
    const radiusM = 1000;

    // Step 2 — Places API で candidatePool を取得
    this.logger.log(
      `DETOUR候補検索: lat=${currentLat}, lng=${currentLng}, radius=${radiusM}m`,
    );
    const candidatePool = await this.placesService.searchNearby(
      currentLat,
      currentLng,
      radiusM,
      20,
    );

    if (candidatePool.length === 0) {
      this.logger.warn('Places API から候補が0件でした');
      return [];
    }

    this.logger.log(`Places API: ${candidatePool.length}件の候補を取得`);

    // Step 3-4 — Gemini に候補集合 + context を渡し DetourCandidate[3] を取得
    const candidates = await this.geminiService.selectDetourCandidates(
      candidatePool,
      now.toISOString(),
      nextItem?.startTime,
      currentLat,
      currentLng,
    );

    this.logger.log(`Gemini: ${candidates.length}件のDETOUR候補を選定`);
    return candidates;
  }
}
