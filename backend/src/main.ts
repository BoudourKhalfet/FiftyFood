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
  app.enableCors({
    origin: '*', // Allow all origins for dev. For production, specify your allowed origins!
    credentials: true,
  });

  await app.listen(port, '0.0.0.0');

  console.log(`Listening on http://127.0.0.1:${port}`);
}
void bootstrap();
