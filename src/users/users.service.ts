/**
 * 仕様書_アーキテクチャ §5.2 / API仕様 §2-4: Backend の役割
 *
 * - userId から Firestore の plan を取得
 * - 判定ロジックで ok/warn/broken を返す
 * - broken時 options を生成し lastBroken に保存
 * - apply で plan を更新
 * - enrich で plan を補完して保存
 */
//test

import { Injectable, Logger } from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import { FirestoreService } from '../firestore/firestore.service.js';
import { PlacesService } from '../google/places.service.js';
import { RoutesService } from '../google/routes.service.js';
import type { Plan, PlanItem } from '../types/plan.types.js';
import type { UserDoc } from '../types/user-doc.types.js';
import type { CheckResponse } from '../types/check-api.types.js';
import type { ApplyOptionResponse, ApplyOptionChoice } from '../types/apply-option-api.types.js';
import type { LastBroken } from '../types/broken.types.js';
import type { EnrichPlanResponse } from '../types/enrich-plan-api.types.js';
import type { EnrichPlanItemInputDto } from './dto/enrich-plan.dto.js';
import { CheckService } from './services/check.service.js';
import { ApplyOptionService } from './services/apply-option.service.js';

/**
 * ISO 8601 文字列から秒を減算し、元のタイムゾーンオフセットを維持した ISO を返す。
 * toISOString() は UTC に変換するため使用しない（Routes API 等は +09:00 等のオフセット付きを期待）。
 */
function subtractSecondsFromISO(isoStr: string, seconds: number): string {
  const offsetMatch = isoStr.match(/([+-])(\d{2}):(\d{2})$/);
  const offsetStr = offsetMatch ? `${offsetMatch[1]}${offsetMatch[2]}:${offsetMatch[3]}` : '+00:00';
  const offsetMinutes = offsetMatch
    ? (offsetMatch[1] === '+' ? 1 : -1) * (parseInt(offsetMatch[2], 10) * 60 + parseInt(offsetMatch[3], 10))
    : 0;

  const ms = new Date(isoStr).getTime() - seconds * 1000;
  const localMs = ms + offsetMinutes * 60 * 1000;
  const ld = new Date(localMs);
  const y = ld.getUTCFullYear();
  const mo = ld.getUTCMonth() + 1;
  const d = ld.getUTCDate();
  const h = ld.getUTCHours();
  const min = ld.getUTCMinutes();
  const s = ld.getUTCSeconds();
  return `${y}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}T${String(h).padStart(2, '0')}:${String(min).padStart(2, '0')}:${String(s).padStart(2, '0')}${offsetStr}`;
}

function subtractMinutesFromISO(isoStr: string, minutes: number): string {
  return subtractSecondsFromISO(isoStr, minutes * 60);
}

/** デバッグモード: ON の場合 enrichPlan 保存後に check を即時実行（破綻判定テスト用） */
const DEBUG_CHECK_AFTER_ENRICH =
  process.env.FLEXIVEL_DEBUG_MODE === '1' || process.env.FLEXIVEL_DEBUG_MODE === 'true';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private readonly firestoreService: FirestoreService,
    private readonly placesService: PlacesService,
    private readonly routesService: RoutesService,
    private readonly checkService: CheckService,
    private readonly applyOptionService: ApplyOptionService,
  ) {
    if (DEBUG_CHECK_AFTER_ENRICH) {
      this.logger.warn('[DEBUG] FLEXIVEL_DEBUG_MODE=1: enrichPlan 保存後に check を即時実行');
    }
  }

  // ────────────────────────────────────────────
  // POST /check（§2）
  // ────────────────────────────────────────────
  async check(
    userId: string,
    now: string,
    currentLat: number,
    currentLng: number,
  ): Promise<CheckResponse> {
    const userDoc = await this.getUserDoc(userId);

    // plan が存在しない → ok（§6 例外方針）
    if (!userDoc || !userDoc.plan) {
      return { status: 'ok' };
    }

    const result = await this.checkService.check(
      userDoc.plan.items,
      new Date(now),
      currentLat,
      currentLng,
    );

    // §2.4 副作用: broken時は lastBroken を Firestore に上書き保存
    if (result.status === 'broken' && result.options) {
      console.log('[破綻通知] broken 判定: targetItemId=%s, options=%d件', result.targetItemId, result.options.length);
      const lastBroken: LastBroken = {
        createdAt: now,
        targetItemId: result.targetItemId!,
        options: result.options,
      };
      await this.saveLastBroken(userId, lastBroken);
    }

    return result;
  }

  // ────────────────────────────────────────────
  // POST /apply-option（§3）
  // ────────────────────────────────────────────
  async applyOption(
    userId: string,
    targetItemId: string,
    choice: ApplyOptionChoice,
  ): Promise<ApplyOptionResponse> {
    const userDoc = await this.getUserDoc(userId);
    if (!userDoc || !userDoc.plan) {
      return { status: 'error', message: 'plan が存在しません。' };
    }

    const result = this.applyOptionService.apply(
      userDoc.plan,
      targetItemId,
      choice,
      userDoc.lastBroken,
    );

    // §3.5 適用成功 → plan 保存 & lastBroken クリア
    if (result.status === 'ok' && result.updatedPlan) {
      await this.savePlan(userId, result.updatedPlan);
      await this.clearLastBroken(userId);
    }

    return result;
  }

  // ────────────────────────────────────────────
  // POST /enrich-plan（§4）
  // Places API で placeId/lat/lng/closeTime を補完し、
  // Routes API で移動時間を取得して deadline = closeTime - stayMinutes - 移動時間 を算出
  // ────────────────────────────────────────────
  async enrichPlan(
    userId: string,
    planId: string,
    createdAt: string,
    items: EnrichPlanItemInputDto[],
  ): Promise<EnrichPlanResponse> {
    const enrichedItems: PlanItem[] = [];

    // 第1パス: placeId/lat/lng/closeTime を取得（deadline は後で算出）
    // 開店・閉店時間は Places API のみから取得。取れない場合は closeTime 未設定
    for (let idx = 0; idx < items.length; idx++) {
      const item = items[idx]!;
      let placeId = '';
      let lat = 0;
      let lng = 0;
      let closeTime: string | undefined;

      let name = item.name;
      let address: string | undefined;

      if (item.placeId) {
        const detail = await this.placesService.getPlaceDetail(item.placeId);
        if (detail) {
          placeId = detail.placeId;
          lat = detail.lat;
          lng = detail.lng;
          name = detail.name;
          address = detail.address;
          closeTime = detail.closeTime;
        } else {
          this.logger.warn(`PlaceDetail取得失敗: placeId=${item.placeId}`);
        }
      } else {
        const placeResult = await this.placesService.searchText(item.name);

        if (placeResult) {
          placeId = placeResult.placeId;
          lat = placeResult.lat;
          lng = placeResult.lng;
          name = placeResult.name;
          address = placeResult.address;

          const detail = await this.placesService.getPlaceDetail(placeId);
          closeTime = detail?.closeTime;
        } else {
          this.logger.warn(`Places検索失敗: "${item.name}" → placeId未取得`);
        }
      }

      enrichedItems.push({
        id: item.id,
        name,
        placeId,
        lat,
        lng,
        address,
        startTime: item.startTime,
        stayMinutes: item.stayMinutes,
        closeTime,
        deadline: undefined,
      });
    }

    // startTime 昇順でソート
    enrichedItems.sort(
      (a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime(),
    );

    // 第2パス: Routes API で移動時間を取得し deadline を算出
    // deadline = closeTime - stayMinutes - 移動時間（prev → current）
    for (let i = 0; i < enrichedItems.length; i++) {
      const curr = enrichedItems[i]!;

      if (i === 0) {
        // 先頭: prev なし → startTime - 10分を締切（出発準備用）
        curr.deadline = subtractMinutesFromISO(curr.startTime, 10);
      } else if (curr.closeTime) {
        // arrivalTime = closeTime - stayMinutes（タイムゾーン維持、toISOString() 禁止）
        const arrivalTime = subtractMinutesFromISO(curr.closeTime, curr.stayMinutes);

        const prev = enrichedItems[i - 1]!;
        const durationSeconds = await this.routesService.getTransitDurationSeconds(
          prev.lat,
          prev.lng,
          curr.lat,
          curr.lng,
          arrivalTime,
        );

        if (durationSeconds != null) {
          curr.deadline = subtractSecondsFromISO(arrivalTime, durationSeconds);
        } else {
          // Routes API 失敗時はフォールバック: 固定10分バッファ
          curr.deadline = subtractMinutesFromISO(arrivalTime, 10);
          this.logger.warn(
            `Routes API 失敗のため ${curr.name} の deadline は10分バッファで算出`,
          );
        }
      }
      // closeTime が無い予定は deadline 未設定 → 判定対象外（仕様書 §3）
    }

    const plan: Plan = { planId, createdAt, items: enrichedItems };

    // §4.4 保存
    await this.savePlan(userId, plan);

    // デバッグモード: 保存直後に check を実行し破綻判定（duration=999999 で到達不可能のため即 broken）
    if (DEBUG_CHECK_AFTER_ENRICH && enrichedItems.length > 0) {
      const now = new Date().toISOString();
      const first = enrichedItems[0]!;
      this.logger.log(`[DEBUG] enrichPlan 保存後、check を即時実行 (userId=${userId})`);
      await this.check(userId, now, first.lat, first.lng);
    }

    this.logger.log(`enrichPlan(${userId}): ${enrichedItems.length}件を補完して保存`);
    return { status: 'ok', plan };
  }

  // ────────────────────────────────────────────
  // Firestore アクセス
  // ────────────────────────────────────────────

  /** users/{userId} ドキュメントを取得 */
  private async getUserDoc(userId: string): Promise<UserDoc | null> {
    const ref = this.firestoreService.userDocRef(userId);
    const snap = await ref.get();
    if (!snap.exists) {
      return null;
    }
    return snap.data() as UserDoc;
  }

  /** users/{userId}.plan を上書き保存 + updatedAt 更新 */
  private async savePlan(userId: string, plan: Plan): Promise<void> {
    const ref = this.firestoreService.userDocRef(userId);
    // Firestore は undefined を許容しないため除外してから保存
    const planForFirestore = this.removeUndefined(plan);
    await ref.set(
      {
        plan: planForFirestore,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
    this.logger.log(`savePlan(${userId}): plan を保存しました`);
  }

  /** オブジェクトから undefined を再帰的に除外（Firestore 用） */
  private removeUndefined<T>(obj: T): T {
    if (obj === undefined || obj === null) {
      return obj;
    }
    if (Array.isArray(obj)) {
      return obj.map((item) => this.removeUndefined(item)) as T;
    }
    if (typeof obj === 'object') {
      const result: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(obj)) {
        if (v !== undefined) {
          result[k] = this.removeUndefined(v);
        }
      }
      return result as T;
    }
    return obj;
  }

  /** users/{userId}.lastBroken を上書き保存（§9） */
  private async saveLastBroken(
    userId: string,
    lastBroken: LastBroken,
  ): Promise<void> {
    const ref = this.firestoreService.userDocRef(userId);
    const lastBrokenForFirestore = this.removeUndefined(lastBroken);
    await ref.set(
      {
        lastBroken: lastBrokenForFirestore,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
    this.logger.log(`saveLastBroken(${userId}): lastBroken を保存しました`);
  }

  /** users/{userId}.lastBroken をクリア（§3.5） */
  private async clearLastBroken(userId: string): Promise<void> {
    const ref = this.firestoreService.userDocRef(userId);
    await ref.update({
      lastBroken: FieldValue.delete(),
      updatedAt: new Date().toISOString(),
    });
    this.logger.log(`clearLastBroken(${userId}): lastBroken をクリアしました`);
  }
}
