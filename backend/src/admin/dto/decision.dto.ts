import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class DecisionDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason!: string;
}
