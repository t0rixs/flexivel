/**
 * 仕様書_API仕様: POST /check, POST /apply-option, POST /enrich-plan
 */

import { Controller, Post, Body, Logger } from '@nestjs/common';
import { UsersService } from './users.service.js';
import { CheckRequestDto } from './dto/check.dto.js';
import { ApplyOptionRequestDto } from './dto/apply-option.dto.js';
import { EnrichPlanRequestDto } from './dto/enrich-plan.dto.js';
import type { CheckResponse } from '../types/check-api.types.js';
import type { ApplyOptionChoice, ApplyOptionResponse } from '../types/apply-option-api.types.js';
import type { EnrichPlanResponse } from '../types/enrich-plan-api.types.js';

@Controller()
export class UsersController {
  private readonly logger = new Logger(UsersController.name);

  constructor(private readonly usersService: UsersService) {}

  /**
   * §2: POST /check
   * 15分おきの判定（ok / warn / broken）
   */
  @Post('check')
  async check(@Body() dto: CheckRequestDto): Promise<CheckResponse> {
    return this.usersService.check(
      dto.userId,
      dto.context.now,
      dto.context.currentLat,
      dto.context.currentLng,
    );
  }

  /**
   * §3: POST /apply-option
   * broken時のユーザー選択を反映し plan 更新
   */
  @Post('apply-option')
  async applyOption(
    @Body() dto: ApplyOptionRequestDto,
  ): Promise<ApplyOptionResponse> {
    // DTO → ドメイン型変換（class-validator の DTO は union 非対応のため）
    let choice: ApplyOptionChoice;
    if (dto.choice.kind === 'DETOUR') {
      choice = { kind: 'DETOUR', detourPlaceId: dto.choice.detourPlaceId! };
    } else {
      choice = { kind: dto.choice.kind };
    }

    return this.usersService.applyOption(
      dto.userId,
      dto.targetItemId,
      choice,
    );
  }

  /**
   * §4: POST /enrich-plan
   * 予定入力を補完して Firestore へ保存
   */
  @Post('enrich-plan')
  async enrichPlan(
    @Body() dto: EnrichPlanRequestDto,
  ): Promise<EnrichPlanResponse> {
    try {
      return await this.usersService.enrichPlan(
        dto.userId,
        dto.plan.planId,
        dto.plan.createdAt,
        dto.plan.items,
      );
    } catch (err) {
      this.logger.error('enrich-plan で例外発生', err);
      const message = err instanceof Error ? err.message : String(err);
      return {
        status: 'error',
        message: `enrich-plan 失敗: ${message}`,
      };
    }
  }
}
