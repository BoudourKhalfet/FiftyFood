import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // Serve local uploads folder at /uploads
  app.useStaticAssets(join(process.cwd(), 'uploads'), {
    prefix: '/uploads',
  });

  const port = Number(process.env.PORT ?? 3000);

  // Bind on IPv4 (fixes Postman/127.0.0.1 connection issues when Nest binds to ::1)
  await app.listen(port, '0.0.0.0');

  console.log(`Listening on http://127.0.0.1:${port}`);
}
void bootstrap();
