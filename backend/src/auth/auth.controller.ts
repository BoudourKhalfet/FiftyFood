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
import { JwtPayload } from './jwt.strategy';
import { Public } from './decorators/public.decorator';
import { RequestPasswordResetDto } from './dto/request-password-reset.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

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

  @Public()
  @Post('request-password-reset')
  async requestPasswordReset(@Body() dto: RequestPasswordResetDto) {
    return this.auth.requestPasswordReset(dto.email);
  }

  @Public()
  @Post('reset-password')
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto.token, dto.newPassword);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@Req() req: RequestWithUser) {
    return this.auth.me(req.user.sub);
  }

  @Public()
  @Get('verify-email')
  async verifyEmail(@Query('token') token: string, @Res() res: Response) {
    try {
      await this.auth.verifyEmail(token);
      return res.send(`
      <html>
        <head><title>Email Verified</title></head>
        <body>
          <h2>Your email has been verified!</h2>
          <p>You can now return to the app and <b>log in to finish your registration</b>.</p>
        </body>
      </html>
    `);
    } catch (e: unknown) {
      const reason =
        e instanceof Error && typeof e.message === 'string'
          ? e.message
          : 'Verification failed.';
      return res.status(400).send(`
      <html>
        <head><title>Verification Failed</title></head>
        <body>
          <h2>Verification failed</h2>
          <p>${reason}</p>
        </body>
      </html>
    `);
    }
  }

  @Public()
  @Post('resend-verification-email')
  async resendVerificationEmail(@Body('email') email: string) {
    await this.auth.resendVerificationEmail(email);
    return { status: 'ok' };
  }
}
