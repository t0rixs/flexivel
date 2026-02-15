/**
 * 仕様書_API仕様 §4: POST /enrich-plan の Request DTO
 * ユーザー入力の予定を Places 等で補完する。
 * placeId / latlng / closeTime / deadline は未入力でもよい。
 */

import {
  IsString,
  IsInt,
  IsArray,
  Min,
  ValidateNested,
  IsOptional,
} from 'class-validator';
import { Type } from 'class-transformer';

export class EnrichPlanItemInputDto {
  @IsString()
  id: string;

  @IsString()
  name: string; // ユーザー入力（オートコンプリート選択時は正式名称）

  /** オートコンプリートで選択した場合: placeId を指定すると searchText をスキップ */
  @IsOptional()
  @IsString()
  placeId?: string;

  @IsString()
  startTime: string; // ユーザー入力（ISO）

  @IsInt()
  @Min(0)
  stayMinutes: number; // ユーザー入力
}

export class EnrichPlanInputDto {
  @IsString()
  planId: string;

  @IsString()
  createdAt: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EnrichPlanItemInputDto)
  items: EnrichPlanItemInputDto[];
}

export class EnrichPlanRequestDto {
  @IsString()
  userId: string;

  @ValidateNested()
  @Type(() => EnrichPlanInputDto)
  plan: EnrichPlanInputDto;

  @IsString()
  transportMode: 'transit';
}
