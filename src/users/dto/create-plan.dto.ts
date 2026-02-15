/**
 * 仕様書_データモデル §3.1: Plan の作成 DTO
 * items は startTime 昇順が前提（サーバ側でソートしてよい）。
 */

import {
  IsString,
  IsArray,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { CreatePlanItemDto } from './create-plan-item.dto.js';

export class CreatePlanDto {
  @IsString()
  planId: string; // UUID

  @IsString()
  createdAt: string; // ISO

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreatePlanItemDto)
  items: CreatePlanItemDto[];
}
