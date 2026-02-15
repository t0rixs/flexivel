/**
 * Google Routes API を使った公共交通機関の移動時間取得。
 * 仕様書: deadline = closeTime - stayMinutes - 移動時間
 * https://developers.google.com/maps/documentation/routes
 *
 * 事前に Google Cloud Console で Routes API を有効化してください。
 */

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** TRANSIT 失敗時のデバッグログを有効化（true で詳細出力） */
const DEBUG_TRANSIT_FAILURE = true;

/** デバッグモード: ON の場合 duration=999999 を返し到達不可能にする（破綻判定テスト用） */
const DEBUG_ROUTES_IMPOSSIBLE =
  process.env.FLEXIVEL_DEBUG_MODE === '1' || process.env.FLEXIVEL_DEBUG_MODE === 'true';

@Injectable()
export class RoutesService {
  private readonly logger = new Logger(RoutesService.name);
  private readonly apiKey: string;

  constructor(private readonly config: ConfigService) {
    this.apiKey = this.config.get<string>('GOOGLE_API_KEY') ?? '';
    if (!this.apiKey) {
      this.logger.warn('GOOGLE_API_KEY が設定されていません');
    }
    if (DEBUG_ROUTES_IMPOSSIBLE) {
      this.logger.warn('[DEBUG] FLEXIVEL_DEBUG_MODE=1: Routes duration を 999999 に固定（到達不可能）');
    }
  }

  /**
   * prev → current の公共交通機関での移動時間（秒）を取得。
   * arrivalTime に到着するルートを検索し、duration を返す。
   * 取得失敗時は null（DRIVE へのフォールバックは行わない）。
   * デバッグモード時は 999999 を返す（到達不可能 → 破綻判定）。
   */
  async getTransitDurationSeconds(
    originLat: number,
    originLng: number,
    destLat: number,
    destLng: number,
    arrivalTime: string, // ISO 8601
  ): Promise<number | null> {
    if (!this.apiKey) return null;

    if (DEBUG_ROUTES_IMPOSSIBLE) {
      this.logger.log('[DEBUG] Routes duration=999999（到達不可能モード）');
      return 999999;
    }

    const waypoints = {
      origin: {
        location: {
          latLng: { latitude: originLat, longitude: originLng },
        },
      },
      destination: {
        location: {
          latLng: { latitude: destLat, longitude: destLng },
        },
      },
    };

    return this._computeRouteDuration({
      ...waypoints,
      travelMode: 'TRANSIT',
      arrivalTime,
      languageCode: 'ja',
      regionCode: 'jp',
    });
  }

  private async _computeRouteDuration(body: Record<string, unknown>): Promise<number | null> {
    const url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    if (DEBUG_TRANSIT_FAILURE) {
      this.logger.log(
        `[Routes DEBUG] リクエスト: ${JSON.stringify(body, null, 2)}`,
      );
    }

    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': this.apiKey,
          'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.legs,routes.warnings,fallbackInfo',
        },
        body: JSON.stringify(body),
      });

      const text = await res.text();

      if (!res.ok) {
        this.logger.warn(
          `Routes API failed: ${res.status} ${text.slice(0, 500)}`,
        );
        if (DEBUG_TRANSIT_FAILURE) {
          this.logger.log(
            `[Routes DEBUG] 失敗レスポンス全文: ${text}`,
          );
          this.logger.log(
            `[Routes DEBUG] レスポンスヘッダー: ${JSON.stringify(Object.fromEntries(res.headers.entries()))}`,
          );
        }
        return null;
      }

      let data: {
        routes?: Array<{ duration?: string; legs?: unknown[]; warnings?: string[] }>;
        fallbackInfo?: unknown;
      };
      try {
        data = JSON.parse(text) as typeof data;
      } catch {
        this.logger.warn(`Routes API: JSON parse failed: ${text.slice(0, 200)}`);
        if (DEBUG_TRANSIT_FAILURE) {
          this.logger.log(`[Routes DEBUG] 生レスポンス: ${text}`);
        }
        return null;
      }

      const durationStr = data.routes?.[0]?.duration;
      if (!durationStr) {
        this.logger.warn(
          `Routes API: routes[0].duration なし (空のroutes?): ${text.slice(0, 300)}`,
        );
        if (DEBUG_TRANSIT_FAILURE) {
          this.logger.log(
            `[Routes DEBUG] レスポンス構造: routes.length=${data.routes?.length ?? 0}, routes[0]=${JSON.stringify(data.routes?.[0])}`,
          );
          this.logger.log(
            `[Routes DEBUG] レスポンス全文: ${text}`,
          );
          if (data.fallbackInfo) {
            this.logger.log(
              `[Routes DEBUG] fallbackInfo: ${JSON.stringify(data.fallbackInfo)}`,
            );
          }
        }
        return null;
      }

      // "165s" 形式をパース
      const match = durationStr.match(/^(\d+(?:\.\d+)?)s$/);
      if (!match) return null;

      const seconds = Math.ceil(parseFloat(match[1]));
      this.logger.log(
        `Routes ${body.travelMode}: duration=${seconds}秒`,
      );
      return seconds;
    } catch (err) {
      this.logger.error('Routes API 呼び出しに失敗しました', err);
      return null;
    }
  }
}
