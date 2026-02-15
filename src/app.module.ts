import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { FirestoreModule } from './firestore/firestore.module.js';
import { GoogleModule } from './google/google.module.js';
import { PlacesModule } from './places/places.module.js';
import { UsersModule } from './users/users.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }), // .env を読み込み
    FirestoreModule,
    GoogleModule,
    PlacesModule,
    UsersModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
