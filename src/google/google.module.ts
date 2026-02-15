import { Global, Module } from '@nestjs/common';
import { PlacesService } from './places.service.js';
import { GeminiService } from './gemini.service.js';
import { RoutesService } from './routes.service.js';

@Global()
@Module({
  providers: [PlacesService, GeminiService, RoutesService],
  exports: [PlacesService, GeminiService, RoutesService],
})
export class GoogleModule {}
