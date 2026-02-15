/**
 * Google Gemini API を使った DETOUR 候補選定サービス。
 * 開店・閉店時間は Places API から取得する。
 */

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenAI } from '@google/genai';
import type { DetourCandidate } from '../types/broken.types.js';
import type { PlaceResult } from './places.service.js';

@Injectable()
export class GeminiService {
  private readonly logger = new Logger(GeminiService.name);
  private readonly ai: GoogleGenAI;

  constructor(private readonly config: ConfigService) {
    const apiKey = this.config.get<string>('GOOGLE_API_KEY') ?? '';
    this.ai = new GoogleGenAI({ apiKey });
  }

  /**
   * 仕様書_ロジック §8.2 Step 3-4:
   * 候補集合 + コンテキストを Gemini に渡し、DetourCandidate[3] を返す。
   */
  async selectDetourCandidates(
    candidatePool: PlaceResult[],
    now: string,
    nextStartTime?: string,
    currentLat?: number,
    currentLng?: number,
  ): Promise<DetourCandidate[]> {
    if (candidatePool.length === 0) return [];

    const candidateList = candidatePool
      .map(
        (c, i) =>
          `${i + 1}. name: "${c.name}", placeId: "${c.placeId}", lat: ${c.lat}, lng: ${c.lng}, address: "${c.address}", types: [${c.types.join(', ')}]`,
      )
      .join('\n');

    const prompt = `あなたは旅行プランナーAIです。ユーザーの旅程が破綻したため、寄り道先を3件提案してください。

## コンテキスト
- 現在時刻: ${now}
- 次の予定の開始時刻: ${nextStartTime ?? '不明'}
- 現在地: lat=${currentLat ?? '不明'}, lng=${currentLng ?? '不明'}

## 候補一覧
${candidateList}

## 制約
- 上記候補から最適な3件を選んでください（3件未満の場合はある分だけ）
- 各候補に以下を付与してください:
  - reason: なぜこの場所がおすすめか（日本語、1文）
  - startTime: 到着予想時刻（ISO 8601形式、現在時刻から移動時間を考慮）
  - stayMinutes: おすすめ滞在時間（分、整数）

## 出力形式（JSONのみ、マークダウン不可）
[
  {
    "placeId": "...",
    "name": "...",
    "lat": ...,
    "lng": ...,
    "address": "...",
    "reason": "...",
    "startTime": "...",
    "stayMinutes": ...
  }
]`;

    try {
      const response = await this.ai.models.generateContent({
        model: 'gemini-2.0-flash',
        contents: prompt,
      });

      const text = response.text ?? '';

      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (!jsonMatch) {
        this.logger.warn('Gemini応答からJSONを抽出できませんでした', text);
        return [];
      }

      const parsed = JSON.parse(jsonMatch[0]) as DetourCandidate[];

      return parsed.slice(0, 3).map((c) => ({
        placeId: c.placeId,
        name: c.name,
        lat: c.lat,
        lng: c.lng,
        address: c.address,
        reason: c.reason,
        startTime: c.startTime,
        stayMinutes: c.stayMinutes,
      }));
    } catch (err) {
      this.logger.error('Gemini API 呼び出しに失敗しました', err);
      return [];
    }
  }
}
