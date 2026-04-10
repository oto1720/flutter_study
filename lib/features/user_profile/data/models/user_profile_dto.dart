import 'package:json_annotation/json_annotation.dart';
import 'package:flutter_learn/features/user_profile/domain/entities/user_profile.dart';

part 'user_profile_dto.g.dart';

/// JSONPlaceholder API の /users/{id} レスポンス DTO
///
/// Data 層の型。Domain 層の UserProfile には toEntity() で変換する。
/// json_serializable でシリアライズ・デシリアライズを自動生成する。
@JsonSerializable()
class UserProfileDto {
  const UserProfileDto({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.website,
    required this.company,
  });

  final int id;
  final String name;
  final String email;
  final String phone;
  final String website;
  final CompanyDto company;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) =>
      _$UserProfileDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileDtoToJson(this);

  /// DTO → Domain エンティティへの変換
  UserProfile toEntity() => UserProfile(
        id: id,
        name: name,
        email: email,
        phone: phone,
        website: website,
        companyName: company.name,
      );
}

@JsonSerializable()
class CompanyDto {
  const CompanyDto({required this.name});

  final String name;

  factory CompanyDto.fromJson(Map<String, dynamic> json) =>
      _$CompanyDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CompanyDtoToJson(this);
}
