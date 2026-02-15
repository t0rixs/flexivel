/**
 * Google Places API (New) を使った場所検索・詳細取得サービス。
 * https://developers.google.com/maps/documentation/places/web-service
 */

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** Places API の近隣検索結果 1件 */
export interface PlaceResult {
  placeId: string;
  name: string;
  lat: number;
  lng: number;
  address: string;
  types: string[];
}

/** Autocomplete の候補1件 */
export interface PlaceAutocompletePrediction {
  placeId: string;
  mainText: string;
  secondaryText: string;
  fullText: string;
}

/** Places API の詳細結果（営業時間含む） */
export interface PlaceDetail {
  placeId: string;
  name: string;
  lat: number;
  lng: number;
  address: string;
  closeTime?: string; // ISO（当日の閉店時刻。取得できない場合は undefined）
}

@Injectable()
export class PlacesService {
  private readonly logger = new Logger(PlacesService.name);
  private readonly apiKey: string;

  constructor(private readonly config: ConfigService) {
    this.apiKey = this.config.get<string>('GOOGLE_API_KEY') ?? '';
    if (!this.apiKey) {
      this.logger.warn('GOOGLE_API_KEY が設定されていません');
    }
  }

  // ────────────────────────────────────────────
  // 近隣検索（Nearby Search - New）
  // ────────────────────────────────────────────
  async searchNearby(
    lat: number,
    lng: number,
    radiusM: number = 1000,
    maxResults: number = 20,
  ): Promise<PlaceResult[]> {
    const url = 'https://places.googleapis.com/v1/places:searchNearby';

    const body = {
      includedTypes: [
        'cafe',
        'restaurant',
        'book_store',
        'shopping_mall',
        'park',
        'museum',
        'art_gallery',
        'tourist_attraction',
      ],
      maxResultCount: maxResults,
      locationRestriction: {
        circle: {
          center: { latitude: lat, longitude: lng },
          radius: radiusM,
        },
      },
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': this.apiKey,
        'X-Goog-FieldMask':
          'places.id,places.displayName,places.location,places.formattedAddress,places.types',
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const text = await res.text();
      this.logger.error(`Places searchNearby failed: ${res.status} ${text}`);
      return [];
    }

    const data = (await res.json()) as any;
    const places: PlaceResult[] = (data.places ?? []).map((p: any) => ({
      placeId: p.id ?? '',
      name: p.displayName?.text ?? '',
      lat: p.location?.latitude ?? 0,
      lng: p.location?.longitude ?? 0,
      address: p.formattedAddress ?? '',
      types: p.types ?? [],
    }));

    this.logger.log(`searchNearby: ${places.length}件の候補を取得`);
    return places;
  }

  // ────────────────────────────────────────────
  // オートコンプリート（入力中の予測変換）
  // ────────────────────────────────────────────
  async autocomplete(
    input: string,
    lat?: number,
    lng?: number,
  ): Promise<PlaceAutocompletePrediction[]> {
    if (!input || input.trim().length < 2) return [];

    const url = 'https://places.googleapis.com/v1/places:autocomplete';

    const body: Record<string, unknown> = {
      input: input.trim(),
      languageCode: 'ja',
      includedRegionCodes: ['jp'],
    };

    if (lat != null && lng != null) {
      body.locationBias = {
        circle: {
          center: { latitude: lat, longitude: lng },
          radius: 50000,
        },
      };
    }

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': this.apiKey,
        'X-Goog-FieldMask':
          'suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat',
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const text = await res.text();
      this.logger.error(`Places autocomplete failed: ${res.status} ${text}`);
      return [];
    }

    const data = (await res.json()) as any;
    const suggestions: PlaceAutocompletePrediction[] = [];

    for (const s of data.suggestions ?? []) {
      const pp = s.placePrediction;
      if (!pp) continue;

      // placeId: "ChIJ..." または place: "places/ChIJ..." から抽出
      const placeId =
        pp.placeId ?? (typeof pp.place === 'string' ? pp.place.replace(/^places\//, '') : '');
      if (!placeId) continue;

      const mainText = pp.structuredFormat?.mainText?.text ?? pp.text?.text ?? '';
      const secondaryText = pp.structuredFormat?.secondaryText?.text ?? '';
      const fullText = (pp.text?.text ?? `${mainText} ${secondaryText}`.trim()) || mainText;

      suggestions.push({ placeId, mainText, secondaryText, fullText });
    }

    return suggestions;
  }

  // ────────────────────────────────────────────
  // テキスト検索（場所名 → placeId / latlng 取得）
  // ────────────────────────────────────────────
  async searchText(query: string): Promise<PlaceResult | null> {
    const url = 'https://places.googleapis.com/v1/places:searchText';

    const body = {
      textQuery: query,
      maxResultCount: 1,
      languageCode: 'ja',
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': this.apiKey,
        'X-Goog-FieldMask':
          'places.id,places.displayName,places.location,places.formattedAddress,places.types',
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const text = await res.text();
      this.logger.error(`Places searchText failed: ${res.status} ${text}`);
      return null;
    }

    const data = (await res.json()) as any;
    const p = data.places?.[0];
    if (!p) return null;

    return {
      placeId: p.id ?? '',
      name: p.displayName?.text ?? '',
      lat: p.location?.latitude ?? 0,
      lng: p.location?.longitude ?? 0,
      address: p.formattedAddress ?? '',
      types: p.types ?? [],
    };
  }

  // ────────────────────────────────────────────
  // 場所詳細（営業時間 → closeTime 取得）
  // ────────────────────────────────────────────
  async getPlaceDetail(placeId: string): Promise<PlaceDetail | null> {
    const url = `https://places.googleapis.com/v1/places/${placeId}`;

    const res = await fetch(url, {
      method: 'GET',
      headers: {
        'X-Goog-Api-Key': this.apiKey,
        'X-Goog-FieldMask':
          'id,displayName,location,formattedAddress,currentOpeningHours,regularOpeningHours,utcOffsetMinutes',
      },
    });

    if (!res.ok) {
      const text = await res.text();
      this.logger.error(`Places getDetail failed: ${res.status} ${text}`);
      return null;
    }

    const p = (await res.json()) as any;

    // 当日の閉店時刻を抽出（place のローカルタイムゾーンで解釈）
    const utcOffsetMinutes = p.utcOffsetMinutes ?? 9 * 60; // 未取得時は JST (UTC+9)
    const closeTime =
      this.extractCloseTime(p.currentOpeningHours, utcOffsetMinutes) ??
      this.extractCloseTime(p.regularOpeningHours, utcOffsetMinutes);

    return {
      placeId: p.id ?? placeId,
      name: p.displayName?.text ?? '',
      lat: p.location?.latitude ?? 0,
      lng: p.location?.longitude ?? 0,
      address: p.formattedAddress ?? '',
      closeTime,
    };
  }

  /**
   * OpeningHours から当日の閉店時刻を ISO 文字列で返す。
   * 営業時間は place のローカルタイムゾーン（utcOffsetMinutes）で解釈する。
   */
  private extractCloseTime(
    openingHours: any,
    utcOffsetMinutes: number = 9 * 60,
  ): string | undefined {
    if (!openingHours) return undefined;

    const now = new Date();
    const todayDay = this.getLocalDayOfWeek(now, utcOffsetMinutes);

    // 1. weekdayDescriptions からパース（例: "日曜日: 10:00～21:00" → 21:00）
    // 文字列は place のローカル時刻なのでそのまま使用
    const desc = this.extractCloseFromWeekdayDescriptions(
      openingHours.weekdayDescriptions,
      todayDay,
      now,
      utcOffsetMinutes,
    );
    if (desc) return desc;

    // 2. periods から取得（open.day で当日の営業枠を特定し、close の時刻を使用）
    // API の hour/minute は place のローカル時刻
    if (!openingHours.periods) return undefined;

    for (const period of openingHours.periods) {
      const openDay = period.open?.day ?? period.open?.dayOfWeek;
      const openDayNum =
        typeof openDay === 'number'
          ? openDay
          : this.dayOfWeekToNumber(openDay);
      if (openDayNum === todayDay && period.close?.hour != null) {
        return this.toLocalTimeISO(now, period.close.hour, period.close.minute ?? 0, utcOffsetMinutes);
      }
    }

    return undefined;
  }

  /** utcOffsetMinutes に基づく「今日」の曜日（0=日..6=土） */
  private getLocalDayOfWeek(date: Date, utcOffsetMinutes: number): number {
    const utcMs = date.getTime();
    const localMs = utcMs + utcOffsetMinutes * 60 * 1000;
    const localDate = new Date(localMs);
    return localDate.getUTCDay();
  }

  /**
   * place のローカル時刻 (hour, minute) をタイムゾーン付き ISO 8601 に変換。
   * API から返る値は place のローカル時刻なのでそのまま使用し、最後にオフセットを付与する。
   */
  private toLocalTimeISO(
    baseDate: Date,
    hour: number,
    minute: number,
    utcOffsetMinutes: number,
  ): string {
    // 1. baseDate をその場所のローカル時間に変換した際の日付を取得する
    // offset を加算して「その場所の時間」の Date オブジェクトを作る
    const localTime = new Date(baseDate.getTime() + utcOffsetMinutes * 60000);

    const y = localTime.getUTCFullYear();
    const m = String(localTime.getUTCMonth() + 1).padStart(2, '0');
    const d = String(localTime.getUTCDate()).padStart(2, '0');
    const hh = String(hour).padStart(2, '0');
    const mm = String(minute).padStart(2, '0');

    // 2. タイムゾーンオフセット文字列を作成 (例: +09:00)
    const sign = utcOffsetMinutes >= 0 ? '+' : '-';
    const absOffset = Math.abs(utcOffsetMinutes);
    const oh = String(Math.floor(absOffset / 60)).padStart(2, '0');
    const om = String(absOffset % 60).padStart(2, '0');

    // 結果: 2026-02-14T18:00:00+09:00
    return `${y}-${m}-${d}T${hh}:${mm}:00${sign}${oh}:${om}`;
  }
  /**
   * weekdayDescriptions から当日の閉店時刻を抽出。
   * 形式: "日曜日: 10:00～21:00" / "Mon: 10:00–21:00" → 後半の 21:00 が閉店
   */
  private extractCloseFromWeekdayDescriptions(
    weekdayDescriptions: string[] | undefined,
    todayDay: number,
    baseDate: Date,
    utcOffsetMinutes: number,
  ): string | undefined {
    if (!weekdayDescriptions?.length || todayDay >= weekdayDescriptions.length)
      return undefined;

    const desc = weekdayDescriptions[todayDay];
    if (!desc || typeof desc !== 'string') return undefined;

    // "10:00～21:00" / "10:00–21:00" / "9:00 PM" 形式から閉店時刻（後半）を取得
    // 24h: (\d{1,2}):(\d{2})\s*[～\-–—]\s*(\d{1,2}):(\d{2})
    let closeHour: number;
    let closeMin: number;

    const match24 = desc.match(
      /(\d{1,2}):(\d{2})\s*[～\-–—]\s*(\d{1,2}):(\d{2})/,
    );
    if (match24) {
      closeHour = parseInt(match24[3], 10);
      closeMin = parseInt(match24[4], 10);
    } else {
      // 12h: "10:00 AM – 9:00 PM"
      const match12 = desc.match(
        /\d{1,2}:\d{2}\s*(?:AM|PM)\s*[～\-–—]\s*(\d{1,2}):(\d{2})\s*(AM|PM)/i,
      );
      if (!match12) return undefined;
      closeHour = parseInt(match12[1], 10);
      closeMin = parseInt(match12[2], 10);
      if (match12[3].toUpperCase() === 'PM' && closeHour < 12)
        closeHour += 12;
      else if (match12[3].toUpperCase() === 'AM' && closeHour === 12)
        closeHour = 0;
    }
    if (isNaN(closeHour) || closeHour < 0 || closeHour > 23) return undefined;

    return this.toLocalTimeISO(baseDate, closeHour, closeMin, utcOffsetMinutes);
  }

  private dayOfWeekToNumber(dayOfWeek: string | undefined): number {
    if (dayOfWeek == null) return -1;
    const map: Record<string, number> = {
      SUNDAY: 0,
      MONDAY: 1,
      TUESDAY: 2,
      WEDNESDAY: 3,
      THURSDAY: 4,
      FRIDAY: 5,
      SATURDAY: 6,
    };
    return map[String(dayOfWeek).toUpperCase()] ?? -1;
  }
}
