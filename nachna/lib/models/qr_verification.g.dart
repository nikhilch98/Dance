// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_verification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QRVerificationRequest _$QRVerificationRequestFromJson(
        Map<String, dynamic> json) =>
    QRVerificationRequest(
      qrData: json['qr_data'] as String,
    );

Map<String, dynamic> _$QRVerificationRequestToJson(
        QRVerificationRequest instance) =>
    <String, dynamic>{
      'qr_data': instance.qrData,
    };

QRVerificationResponse _$QRVerificationResponseFromJson(
        Map<String, dynamic> json) =>
    QRVerificationResponse(
      valid: json['valid'] as bool,
      error: json['error'] as String?,
      registrationData: json['registration_data'] == null
          ? null
          : RegistrationData.fromJson(
              json['registration_data'] as Map<String, dynamic>),
      verificationDetails: json['verification_details'] == null
          ? null
          : VerificationDetails.fromJson(
              json['verification_details'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$QRVerificationResponseToJson(
        QRVerificationResponse instance) =>
    <String, dynamic>{
      'valid': instance.valid,
      'error': instance.error,
      'registration_data': instance.registrationData,
      'verification_details': instance.verificationDetails,
    };

RegistrationData _$RegistrationDataFromJson(Map<String, dynamic> json) =>
    RegistrationData(
      orderId: json['order_id'] as String,
      workshop: WorkshopInfo.fromJson(json['workshop'] as Map<String, dynamic>),
      registration: RegistrationInfo.fromJson(
          json['registration'] as Map<String, dynamic>),
      verification: VerificationInfo.fromJson(
          json['verification'] as Map<String, dynamic>),
      payment: json['payment'] == null
          ? null
          : PaymentInfo.fromJson(json['payment'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RegistrationDataToJson(RegistrationData instance) =>
    <String, dynamic>{
      'order_id': instance.orderId,
      'workshop': instance.workshop,
      'registration': instance.registration,
      'verification': instance.verification,
      'payment': instance.payment,
    };

WorkshopInfo _$WorkshopInfoFromJson(Map<String, dynamic> json) => WorkshopInfo(
      uuid: json['uuid'] as String,
      title: json['title'] as String,
      artists:
          (json['artists'] as List<dynamic>).map((e) => e as String).toList(),
      studio: json['studio'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
    );

Map<String, dynamic> _$WorkshopInfoToJson(WorkshopInfo instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'title': instance.title,
      'artists': instance.artists,
      'studio': instance.studio,
      'date': instance.date,
      'time': instance.time,
    };

RegistrationInfo _$RegistrationInfoFromJson(Map<String, dynamic> json) =>
    RegistrationInfo(
      userName: json['user_name'] as String,
      userPhone: json['user_phone'] as String,
      amountPaid: (json['amount_paid'] as num).toDouble(),
      currency: json['currency'] as String,
    );

Map<String, dynamic> _$RegistrationInfoToJson(RegistrationInfo instance) =>
    <String, dynamic>{
      'user_name': instance.userName,
      'user_phone': instance.userPhone,
      'amount_paid': instance.amountPaid,
      'currency': instance.currency,
    };

VerificationInfo _$VerificationInfoFromJson(Map<String, dynamic> json) =>
    VerificationInfo(
      generatedAt: json['generated_at'] as String,
      expiresAt: json['expires_at'] as String,
      nonce: json['nonce'] as String,
    );

Map<String, dynamic> _$VerificationInfoToJson(VerificationInfo instance) =>
    <String, dynamic>{
      'generated_at': instance.generatedAt,
      'expires_at': instance.expiresAt,
      'nonce': instance.nonce,
    };

PaymentInfo _$PaymentInfoFromJson(Map<String, dynamic> json) => PaymentInfo(
      transactionId: json['transaction_id'] as String,
      gateway: json['gateway'] as String,
    );

Map<String, dynamic> _$PaymentInfoToJson(PaymentInfo instance) =>
    <String, dynamic>{
      'transaction_id': instance.transactionId,
      'gateway': instance.gateway,
    };

VerificationDetails _$VerificationDetailsFromJson(Map<String, dynamic> json) =>
    VerificationDetails(
      verifiedAt: json['verified_at'] as String,
      signatureValid: json['signature_valid'] as bool,
      expiresAt: json['expires_at'] as String,
    );

Map<String, dynamic> _$VerificationDetailsToJson(
        VerificationDetails instance) =>
    <String, dynamic>{
      'verified_at': instance.verifiedAt,
      'signature_valid': instance.signatureValid,
      'expires_at': instance.expiresAt,
    };
