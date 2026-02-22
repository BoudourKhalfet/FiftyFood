import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response, Request } from 'express';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { JwtPayload } from './jwt.strategy';
import { Public } from './decorators/public.decorator';

type RequestWithUser = Request & { user: JwtPayload };

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Public()
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() req: RequestWithUser) {
    return this.auth.me(req.user.sub);
  }

  @Public()
  @Get('verify-email')
  async verifyEmail(@Query('token') token: string, @Res() res: Response) {
    const landing =
      process.env.EMAIL_VERIFY_LANDING_URL || 'http://localhost:5173/verified';

    try {
      await this.auth.verifyEmail(token);
      return res.redirect(`${landing}?status=success`);
    } catch (e: unknown) {
      const reason =
        e instanceof Error && typeof e.message === 'string'
          ? e.message
          : 'verification_failed';

      return res.redirect(
        `${landing}?status=error&reason=${encodeURIComponent(reason)}`,
      );
    }
  }
}
