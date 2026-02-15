import { Module } from '@nestjs/common';
import { PlacesController } from './places.controller.js';
import { GoogleModule } from '../google/google.module.js';

@Module({
  imports: [GoogleModule],
  controllers: [PlacesController],
})
export class PlacesModule {}
