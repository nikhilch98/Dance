import 'package:json_annotation/json_annotation.dart';

part 'qr_verification.g.dart';

@JsonSerializable()
class QRVerificationRequest {
  @JsonKey(name: 'qr_data')
  final String qrData;

  QRVerificationRequest({
    required this.qrData,
  });

  factory QRVerificationRequest.fromJson(Map<String, dynamic> json) =>
      _$QRVerificationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$QRVerificationRequestToJson(this);
}

@JsonSerializable()
class QRVerificationResponse {
  final bool valid;
  final String? error;
  @JsonKey(name: 'registration_data')
  final RegistrationData? registrationData;
  @JsonKey(name: 'verification_details')
  final VerificationDetails? verificationDetails;

  QRVerificationResponse({
    required this.valid,
    this.error,
    this.registrationData,
    this.verificationDetails,
  });

  factory QRVerificationResponse.fromJson(Map<String, dynamic> json) =>
      _$QRVerificationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$QRVerificationResponseToJson(this);
}

@JsonSerializable()
class RegistrationData {
  @JsonKey(name: 'order_id')
  final String orderId;
  final WorkshopInfo workshop;
  final RegistrationInfo registration;
  final VerificationInfo verification;
  final PaymentInfo? payment;

  RegistrationData({
    required this.orderId,
    required this.workshop,
    required this.registration,
    required this.verification,
    this.payment,
  });

  factory RegistrationData.fromJson(Map<String, dynamic> json) =>
      _$RegistrationDataFromJson(json);

  Map<String, dynamic> toJson() => _$RegistrationDataToJson(this);

  String get formattedOrderId {
    return 'NACHNA-${orderId.substring(0, 8).toUpperCase()}';
  }

  String get shortOrderId {
    return orderId.substring(0, 8).toUpperCase();
  }
}

@JsonSerializable()
class WorkshopInfo {
  final String uuid;
  final String title;
  final List<String> artists;
  final String studio;
  final String date;
  final String time;

  WorkshopInfo({
    required this.uuid,
    required this.title,
    required this.artists,
    required this.studio,
    required this.date,
    required this.time,
  });

  factory WorkshopInfo.fromJson(Map<String, dynamic> json) =>
      _$WorkshopInfoFromJson(json);

  Map<String, dynamic> toJson() => _$WorkshopInfoToJson(this);

  String get artistNames => artists.join(', ');
}

@JsonSerializable()
class RegistrationInfo {
  @JsonKey(name: 'user_name')
  final String userName;
  @JsonKey(name: 'user_phone')
  final String userPhone;
  @JsonKey(name: 'amount_paid')
  final double amountPaid;
  final String currency;

  RegistrationInfo({
    required this.userName,
    required this.userPhone,
    required this.amountPaid,
    required this.currency,
  });

  factory RegistrationInfo.fromJson(Map<String, dynamic> json) =>
      _$RegistrationInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RegistrationInfoToJson(this);

  String get formattedAmount => '₹${amountPaid.toStringAsFixed(2)}';
  
  String get maskedPhone {
    if (userPhone.length >= 10) {
      final last4 = userPhone.substring(userPhone.length - 4);
      return 'XXXXXX$last4';
    }
    return userPhone;
  }
}

@JsonSerializable()
class VerificationInfo {
  @JsonKey(name: 'generated_at')
  final String generatedAt;
  @JsonKey(name: 'expires_at')
  final String expiresAt;
  final String nonce;

  VerificationInfo({
    required this.generatedAt,
    required this.expiresAt,
    required this.nonce,
  });

  factory VerificationInfo.fromJson(Map<String, dynamic> json) =>
      _$VerificationInfoFromJson(json);

  Map<String, dynamic> toJson() => _$VerificationInfoToJson(this);

  DateTime get generatedDateTime => DateTime.parse(generatedAt);
  DateTime get expiresDateTime => DateTime.parse(expiresAt);
  
  bool get isExpired => DateTime.now().isAfter(expiresDateTime);
  
  String get timeRemaining {
    final now = DateTime.now();
    final expiry = expiresDateTime;
    
    if (now.isAfter(expiry)) {
      return 'Expired';
    }
    
    final difference = expiry.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes left';
    } else {
      return 'Expires soon';
    }
  }
}

@JsonSerializable()
class PaymentInfo {
  @JsonKey(name: 'transaction_id')
  final String transactionId;
  final String gateway;

  PaymentInfo({
    required this.transactionId,
    required this.gateway,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) =>
      _$PaymentInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentInfoToJson(this);
}

@JsonSerializable()
class VerificationDetails {
  @JsonKey(name: 'verified_at')
  final String verifiedAt;
  @JsonKey(name: 'signature_valid')
  final bool signatureValid;
  @JsonKey(name: 'expires_at')
  final String expiresAt;

  VerificationDetails({
    required this.verifiedAt,
    required this.signatureValid,
    required this.expiresAt,
  });

  factory VerificationDetails.fromJson(Map<String, dynamic> json) =>
      _$VerificationDetailsFromJson(json);

  Map<String, dynamic> toJson() => _$VerificationDetailsToJson(this);

  DateTime get verifiedDateTime => DateTime.parse(verifiedAt);
  DateTime get expiresDateTime => DateTime.parse(expiresAt);
}
