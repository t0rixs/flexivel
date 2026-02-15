/**
 * 仕様書_API仕様 §2: POST /check の Request DTO
 * 15分おきの判定リクエスト。
 */

import {
  IsString,
  IsNumber,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CheckContextDto {
  @IsString()
  now: string; // ISO

  @IsNumber()
  currentLat: number;

  @IsNumber()
  currentLng: number;
}

export class CheckRequestDto {
  @IsString()
  userId: string;

  @ValidateNested()
  @Type(() => CheckContextDto)
  context: CheckContextDto;

  @IsString()
  transportMode: 'transit';
}
