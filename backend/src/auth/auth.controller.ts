import {
  Body,
  Controller,
  Get,
  Patch,
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
  async verifyEmail(
    @Query('token') token: string,
    @Res() res: Response,
    @Query('welcome') welcome?: string,
    @Query('changeEmail') changeEmail?: string,
  ) {
    try {
      await this.auth.verifyEmail(token, welcome, changeEmail === '1');
      return res.send(`
        <html>
          <body style="font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f9fafb;">
            <div style="text-align: center; padding: 2rem; background: white; border-radius: 8px; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);">
              <h1 style="color: #059669; margin-bottom: 1rem;">Email Vérifié !</h1>
              <p style="color: #4b5563;">Votre compte a été activé avec succès.</p>
              <p style="color: #6b7280; font-size: 0.875rem; margin-top: 1rem;">Vous pouvez maintenant retourner sur l'application.</p>
            </div>
          </body>
        </html>
      `);
    } catch (e: unknown) {
      const reason =
        e instanceof Error && typeof e.message === 'string'
          ? e.message
          : 'La vérification a échoué.';

      return res.status(400).send(`
        <html>
          <body style="font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #fef2f2;">
            <div style="text-align: center; padding: 2rem; background: white; border-radius: 8px; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);">
              <h1 style="color: #dc2626; margin-bottom: 1rem;">Erreur</h1>
              <p style="color: #4b5563;">${reason}</p>
              <p style="color: #6b7280; font-size: 0.875rem; margin-top: 1rem;">Le lien est peut-être expiré ou invalide.</p>
            </div>
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

  @Post('request-email-change')
  @UseGuards(JwtAuthGuard)
  async requestEmailChange(
    @Req() req: RequestWithUser,
    @Body('email') email: string,
  ) {
    const authService = this.auth as AuthService & {
      requestEmailChange(
        userId: string,
        newEmail: string,
      ): Promise<{ message: string }>;
    };
    return await authService.requestEmailChange(req.user.sub, email);
  }

  @Patch('change-password')
  @UseGuards(JwtAuthGuard)
  async changePassword(
    @Req() req: RequestWithUser,
    @Body() body: { oldPassword: string; newPassword: string },
  ) {
    return this.auth.changePassword(
      req.user.sub,
      body.oldPassword,
      body.newPassword,
    );
  }
}
