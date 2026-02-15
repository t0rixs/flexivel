/**
 * Firebase Admin SDK を使った Firestore アクセスサービス。
 * Cloud Run では ADC（Application Default Credentials）で自動認証。
 * ローカル開発では GOOGLE_APPLICATION_CREDENTIALS 環境変数 or Firebase Emulator を使用。
 */

import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { initializeApp, getApps, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

@Injectable()
export class FirestoreService implements OnModuleInit {
  private readonly logger = new Logger(FirestoreService.name);
  private db: Firestore;

  onModuleInit() {
    let app: App;
    if (getApps().length === 0) {
      // GOOGLE_APPLICATION_CREDENTIALS が設定されていればそれを使用
      // Cloud Run では ADC で自動認証
      app = initializeApp({ projectId: 'flexivel' });
      this.logger.log('Firebase Admin SDK を初期化しました (projectId: flexivel)');
    } else {
      app = getApps()[0];
    }
    this.db = getFirestore(app);
  }

  /** Firestore インスタンスを取得 */
  getDb(): Firestore {
    return this.db;
  }

  /** users/{userId} ドキュメントの参照を取得 */
  userDocRef(userId: string) {
    return this.db.collection('users').doc(userId);
  }
}
