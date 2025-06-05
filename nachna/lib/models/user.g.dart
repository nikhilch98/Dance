// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      userId: json['user_id'] as String,
      mobileNumber: json['mobile_number'] as String,
      name: json['name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      profileComplete: json['profile_complete'] as bool,
      isAdmin: json['is_admin'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'user_id': instance.userId,
      'mobile_number': instance.mobileNumber,
      'name': instance.name,
      'date_of_birth': instance.dateOfBirth,
      'gender': instance.gender,
      'profile_picture_url': instance.profilePictureUrl,
      'profile_complete': instance.profileComplete,
      'is_admin': instance.isAdmin,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'token_type': instance.tokenType,
      'user': instance.user,
    };

UserRegistration _$UserRegistrationFromJson(Map<String, dynamic> json) =>
    UserRegistration(
      mobileNumber: json['mobile_number'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$UserRegistrationToJson(UserRegistration instance) =>
    <String, dynamic>{
      'mobile_number': instance.mobileNumber,
      'password': instance.password,
    };

UserLogin _$UserLoginFromJson(Map<String, dynamic> json) => UserLogin(
      mobileNumber: json['mobile_number'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$UserLoginToJson(UserLogin instance) => <String, dynamic>{
      'mobile_number': instance.mobileNumber,
      'password': instance.password,
    };

ProfileUpdate _$ProfileUpdateFromJson(Map<String, dynamic> json) =>
    ProfileUpdate(
      name: json['name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
    );

Map<String, dynamic> _$ProfileUpdateToJson(ProfileUpdate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'date_of_birth': instance.dateOfBirth,
      'gender': instance.gender,
    };

PasswordUpdate _$PasswordUpdateFromJson(Map<String, dynamic> json) =>
    PasswordUpdate(
      currentPassword: json['current_password'] as String,
      newPassword: json['new_password'] as String,
    );

Map<String, dynamic> _$PasswordUpdateToJson(PasswordUpdate instance) =>
    <String, dynamic>{
      'current_password': instance.currentPassword,
      'new_password': instance.newPassword,
    };

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => AppConfig(
      isAdmin: json['is_admin'] as bool,
      deviceToken: json['device_token'] as String?,
    );

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'is_admin': instance.isAdmin,
      'device_token': instance.deviceToken,
    };
