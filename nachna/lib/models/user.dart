import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  @JsonKey(name: 'user_id')
  final String userId;
  
  @JsonKey(name: 'mobile_number')
  final String mobileNumber;
  
  final String? name;
  
  @JsonKey(name: 'date_of_birth')
  final String? dateOfBirth;
  
  final String? gender;
  
  @JsonKey(name: 'profile_picture_url')
  final String? profilePictureUrl;
  
  @JsonKey(name: 'profile_complete')
  final bool profileComplete;
  
  @JsonKey(name: 'is_admin')
  final bool? isAdmin;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  User({
    required this.userId,
    required this.mobileNumber,
    this.name,
    this.dateOfBirth,
    this.gender,
    this.profilePictureUrl,
    required this.profileComplete,
    this.isAdmin,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? userId,
    String? mobileNumber,
    String? name,
    String? dateOfBirth,
    String? gender,
    String? profilePictureUrl,
    bool? profileComplete,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      userId: userId ?? this.userId,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      profileComplete: profileComplete ?? this.profileComplete,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@JsonSerializable()
class AuthResponse {
  @JsonKey(name: 'access_token')
  final String accessToken;
  
  @JsonKey(name: 'token_type')
  final String tokenType;
  
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable()
class UserRegistration {
  @JsonKey(name: 'mobile_number')
  final String mobileNumber;
  
  final String password;

  UserRegistration({
    required this.mobileNumber,
    required this.password,
  });

  factory UserRegistration.fromJson(Map<String, dynamic> json) => _$UserRegistrationFromJson(json);
  Map<String, dynamic> toJson() => _$UserRegistrationToJson(this);
}

@JsonSerializable()
class UserLogin {
  @JsonKey(name: 'mobile_number')
  final String mobileNumber;
  
  final String password;

  UserLogin({
    required this.mobileNumber,
    required this.password,
  });

  factory UserLogin.fromJson(Map<String, dynamic> json) => _$UserLoginFromJson(json);
  Map<String, dynamic> toJson() => _$UserLoginToJson(this);
}

@JsonSerializable()
class ProfileUpdate {
  final String? name;
  
  @JsonKey(name: 'date_of_birth')
  final String? dateOfBirth;
  
  final String? gender;

  ProfileUpdate({
    this.name,
    this.dateOfBirth,
    this.gender,
  });

  factory ProfileUpdate.fromJson(Map<String, dynamic> json) => _$ProfileUpdateFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileUpdateToJson(this);
}

@JsonSerializable()
class PasswordUpdate {
  @JsonKey(name: 'current_password')
  final String currentPassword;
  
  @JsonKey(name: 'new_password')
  final String newPassword;

  PasswordUpdate({
    required this.currentPassword,
    required this.newPassword,
  });

  factory PasswordUpdate.fromJson(Map<String, dynamic> json) => _$PasswordUpdateFromJson(json);
  Map<String, dynamic> toJson() => _$PasswordUpdateToJson(this);
}

@JsonSerializable()
class AppConfig {
  @JsonKey(name: 'is_admin')
  final bool isAdmin;

  AppConfig({
    required this.isAdmin,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);
  Map<String, dynamic> toJson() => _$AppConfigToJson(this);
} 