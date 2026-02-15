/**
 * 仕様書_API仕様 §3: POST /apply-option の Request DTO
 * broken時のユーザー選択を反映する。
 */

import {
  IsString,
  IsObject,
  ValidateNested,
  IsIn,
  IsOptional,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * choice の判別
 *  - { kind: "GO_NEXT" }
 *  - { kind: "SKIP" }
 *  - { kind: "DETOUR", detourPlaceId: string }
 */
export class ApplyOptionChoiceDto {
  @IsIn(['GO_NEXT', 'SKIP', 'DETOUR'])
  kind: 'GO_NEXT' | 'SKIP' | 'DETOUR';

  @IsOptional()
  @IsString()
  detourPlaceId?: string; // DETOUR のときのみ
}

export class ApplyOptionRequestDto {
  @IsString()
  userId: string;

  @IsString()
  targetItemId: string;

  @ValidateNested()
  @Type(() => ApplyOptionChoiceDto)
  @IsObject()
  choice: ApplyOptionChoiceDto;

  @IsString()
  transportMode: 'transit';
}
