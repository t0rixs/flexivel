/**
 * 仕様書_データモデル §3.2: PlanItem の入力 DTO
 * ユーザー入力 + Places 補完後のフル情報。
 */

import {
  IsString,
  IsNumber,
  IsOptional,
  IsInt,
  Min,
} from 'class-validator';

export class CreatePlanItemDto {
  @IsString()
  id: string;

  @IsString()
  name: string;

  @IsString()
  placeId: string;

  @IsNumber()
  lat: number;

  @IsNumber()
  lng: number;

  @IsString()
  startTime: string; // ISO 8601

  @IsInt()
  @Min(0)
  stayMinutes: number;

  @IsOptional()
  @IsString()
  closeTime?: string; // ISO（取れない場合は未設定→判定対象外）

  @IsOptional()
  @IsString()
  deadline?: string; // ISO（入力時に逆算して保存）
}
