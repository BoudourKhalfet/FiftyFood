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
  @Post('google')
  async googleSignIn(
    @Body('idToken') idToken: string,
    @Body('role') role: string,
  ) {
    return await this.auth.signInWithGoogle(idToken, role);
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

  @Public()
  @Get('reset-password')
  resetPasswordPage(@Query('token') token: string, @Res() res: Response) {
    const escapedToken = token
      ? token
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;')
          .replace(/"/g, '&quot;')
      : '';

    return res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <title>Reset Password</title>
          <style>
            body { font-family: Arial, sans-serif; background: #f4f7f5; margin: 0; min-height: 100vh; display: grid; place-items: center; color: #1f2937; }
            .card { width: min(92vw, 420px); background: white; border-radius: 20px; padding: 28px; box-shadow: 0 12px 30px rgba(0,0,0,0.12); }
            h1 { margin: 0 0 10px; font-size: 28px; }
            p { line-height: 1.5; color: #4b5563; }
            input, button { width: 100%; box-sizing: border-box; border-radius: 14px; font-size: 16px; }
            input { border: 1px solid #d1d5db; padding: 14px 16px; margin-top: 12px; }
            button { margin-top: 16px; border: none; padding: 14px 16px; background: #2d8066; color: white; font-weight: 700; cursor: pointer; }
            button:disabled { opacity: 0.7; cursor: not-allowed; }
            .error { margin-top: 12px; color: #dc2626; }
            .success { margin-top: 12px; color: #059669; }
            .hidden { display: none; }
            .meta { margin-top: 16px; font-size: 13px; color: #6b7280; }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>Reset Password</h1>
            <p>Enter a new password for your FiftyFood account.</p>
            <input id="token" type="hidden" value="${escapedToken}" />
            <input id="password" type="password" placeholder="New password" autocomplete="new-password" />
            <input id="passwordConfirm" type="password" placeholder="Confirm new password" autocomplete="new-password" />
            <button id="submitBtn" onclick="submitPassword()">Reset Password</button>
            <div id="error" class="error hidden"></div>
            <div id="success" class="success hidden"></div>
            <div class="meta">Password must be at least 8 characters and include uppercase, lowercase, number, and special character.</div>
          </div>
          <script>
            async function submitPassword() {
              const token = document.getElementById('token').value;
              const password = document.getElementById('password').value.trim();
              const passwordConfirm = document.getElementById('passwordConfirm').value.trim();
              const errorEl = document.getElementById('error');
              const successEl = document.getElementById('success');
              const btn = document.getElementById('submitBtn');
              errorEl.classList.add('hidden');
              successEl.classList.add('hidden');

              if (!token) {
                errorEl.textContent = 'Reset token missing.';
                errorEl.classList.remove('hidden');
                return;
              }
              if (!password) {
                errorEl.textContent = 'Please enter a new password.';
                errorEl.classList.remove('hidden');
                return;
              }
              if (password !== passwordConfirm) {
                errorEl.textContent = 'Passwords do not match.';
                errorEl.classList.remove('hidden');
                return;
              }

              btn.disabled = true;
              btn.textContent = 'Resetting...';
              try {
                const response = await fetch('/auth/reset-password', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ token, newPassword: password })
                });
                const data = await response.json();
                if (!response.ok) {
                  throw new Error(data.message || 'Reset failed');
                }
                successEl.textContent = data.message || 'Password reset successful.';
                successEl.classList.remove('hidden');
                btn.textContent = 'Done';
              } catch (err) {
                errorEl.textContent = err.message || 'Reset failed.';
                errorEl.classList.remove('hidden');
                btn.disabled = false;
                btn.textContent = 'Reset Password';
              }
            }
          </script>
        </body>
      </html>
    `);
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
