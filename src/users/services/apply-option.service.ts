/**
 * 仕様書_API仕様 §3: /apply-option のサーバ側適用ルール
 *
 * - GO_NEXT: plan更新なし（現行planを返す）
 * - SKIP:    targetItemId の PlanItem を削除
 * - DETOUR:  targetItemId の PlanItem を候補で置換
 */

import { Injectable, Logger } from '@nestjs/common';
import type { Plan, PlanItem } from '../../types/plan.types.js';
import type { LastBroken } from '../../types/broken.types.js';
import type { ApplyOptionChoice } from '../../types/apply-option-api.types.js';
import type { ApplyOptionResponse } from '../../types/apply-option-api.types.js';

@Injectable()
export class ApplyOptionService {
  private readonly logger = new Logger(ApplyOptionService.name);

  /**
   * ユーザーの choice に基づき plan を更新する。
   *
   * @param plan         現在の Plan
   * @param targetItemId broken 対象の PlanItem.id
   * @param choice       ユーザー選択（GO_NEXT / SKIP / DETOUR）
   * @param lastBroken   Firestoreに保存された lastBroken（DETOUR候補復元用）
   * @returns ApplyOptionResponse
   */
  apply(
    plan: Plan,
    targetItemId: string,
    choice: ApplyOptionChoice,
    lastBroken?: LastBroken,
  ): ApplyOptionResponse {
    switch (choice.kind) {
      // ── GO_NEXT: plan更新なし ──
      case 'GO_NEXT':
        return { status: 'ok', updatedPlan: plan };

      // ── SKIP: targetItemId を削除 ──
      case 'SKIP': {
        const updatedItems = plan.items.filter(
          (item) => item.id !== targetItemId,
        );
        const updatedPlan: Plan = { ...plan, items: updatedItems };
        return { status: 'ok', updatedPlan };
      }

      // ── DETOUR: targetItemId を候補で置換 ──
      case 'DETOUR': {
        // lastBroken が無い場合はエラー（仕様 §6 例外方針）
        if (!lastBroken) {
          return {
            status: 'error',
            message:
              'lastBroken が存在しないため DETOUR を適用できません。',
          };
        }

        // lastBroken.options から DETOUR 候補を復元
        const detourOption = lastBroken.options.find(
          (o) => o.kind === 'DETOUR',
        );
        if (!detourOption || detourOption.kind !== 'DETOUR') {
          return {
            status: 'error',
            message: 'DETOUR候補が見つかりません。',
          };
        }

        // detourPlaceId に一致する候補を特定
        const candidate = detourOption.candidates.find(
          (c) => c.placeId === choice.detourPlaceId,
        );
        if (!candidate) {
          return {
            status: 'error',
            message: `detourPlaceId "${choice.detourPlaceId}" に一致する候補が見つかりません。`,
          };
        }

        // targetItemId の PlanItem を候補で「置換」（§3.4: insertではない）
        const replacedItems: PlanItem[] = plan.items.map((item) => {
          if (item.id !== targetItemId) return item;
          return {
            id: item.id, // IDは維持
            name: candidate.name,
            placeId: candidate.placeId,
            lat: candidate.lat,
            lng: candidate.lng,
            address: candidate.address,
            startTime: candidate.startTime,
            stayMinutes: candidate.stayMinutes,
            // closeTime/deadline は DETOUR 先では未設定（MVPでは再計算しない）
          };
        });

        const updatedPlan: Plan = { ...plan, items: replacedItems };
        return { status: 'ok', updatedPlan };
      }

      default:
        return { status: 'error', message: '不明な choice.kind です。' };
    }
  }
}
