import { Module } from '@nestjs/common';
import { UsersService } from './users.service.js';
import { UsersController } from './users.controller.js';
import { CheckService } from './services/check.service.js';
import { BrokenOptionsService } from './services/broken-options.service.js';
import { ApplyOptionService } from './services/apply-option.service.js';

@Module({
  controllers: [UsersController],
  providers: [
    UsersService,
    CheckService,
    BrokenOptionsService,
    ApplyOptionService,
  ],
})
export class UsersModule {}
