import { Global, Module } from '@nestjs/common';
import { FirestoreService } from './firestore.service.js';

/** アプリ全体で使えるよう @Global() で登録 */
@Global()
@Module({
  providers: [FirestoreService],
  exports: [FirestoreService],
})
export class FirestoreModule {}
