import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // DTO バリデーションを自動適用（class-validator / class-transformer）
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,       // DTO に定義されていないプロパティを除外
      forbidNonWhitelisted: true,
      transform: true,       // リクエストを DTO クラスに自動変換
    }),
  );

  // Cloud Run では PORT 環境変数で指定される
  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');
  console.log(`Server running on port ${port}`);
}
bootstrap();
