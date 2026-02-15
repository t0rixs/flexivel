/**
 * Places API のプロキシエンドポイント
 * フロントエンドからオートコンプリート候補を取得する
 */

import { Controller, Get, Query } from '@nestjs/common';
import { PlacesService } from '../google/places.service.js';

@Controller('places')
export class PlacesController {
  constructor(private readonly placesService: PlacesService) {}

  /**
   * GET /places/autocomplete?input=xxx&lat=35.68&lng=139.76
   * 入力テキストに基づくオートコンプリート候補を返す
   */
  @Get('autocomplete')
  async autocomplete(
    @Query('input') input: string,
    @Query('lat') latStr?: string,
    @Query('lng') lngStr?: string,
  ) {
    const lat = latStr ? parseFloat(latStr) : undefined;
    const lng = lngStr ? parseFloat(lngStr) : undefined;

    const suggestions = await this.placesService.autocomplete(
      input ?? '',
      lat,
      lng,
    );

    return { suggestions };
  }
}
