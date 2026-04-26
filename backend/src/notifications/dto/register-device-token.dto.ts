import { IsEnum, IsString, MaxLength, MinLength } from 'class-validator';

export enum DevicePlatformDto {
  ANDROID = 'ANDROID',
  IOS = 'IOS',
  WEB = 'WEB',
}

export class RegisterDeviceTokenDto {
  @IsString()
  @MinLength(20)
  @MaxLength(4096)
  token!: string;

  @IsEnum(DevicePlatformDto)
  platform!: DevicePlatformDto;
}
