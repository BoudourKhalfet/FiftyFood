/* eslint-disable @typescript-eslint/no-unsafe-call */
import { IsEmail, IsEnum, IsString, MinLength, Matches } from 'class-validator';
import { Role } from '@prisma/client';

export class RegisterDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  @Matches(/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^A-Za-z0-9]).+$/, {
    message:
      'Password must contain at least 1 uppercase letter, 1 lowercase letter, 1 number, and 1 special character.',
  })
  password!: string;

  @IsEnum(Role)
  role!: Role;
}
