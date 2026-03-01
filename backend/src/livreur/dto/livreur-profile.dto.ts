import { IsOptional, IsString } from 'class-validator';

export class LivreurProfileDto {
  @IsString() @IsOptional() fullName?: string;
  @IsString() @IsOptional() phone?: string;
  @IsString() @IsOptional() vehicleType?: string;
  @IsString() @IsOptional() zone?: string;
  @IsString() @IsOptional() cinOrPassportNumber?: string;
  @IsString() @IsOptional() bankAccountNumber?: string;
  @IsString() @IsOptional() licensePhotoUrl?: string;
  @IsString() @IsOptional() vehicleOwnershipDocUrl?: string;
  @IsString() @IsOptional() vehiclePhotoUrl?: string;
}
