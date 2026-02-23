export type TokenScope = 'ACCESS' | 'ONBOARDING';

export type JwtPayloadBase = {
  sub: string;
  role: string;
  status: string;
  scope: TokenScope;
};
