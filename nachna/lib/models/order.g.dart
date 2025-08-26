// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderWorkshopDetails _$OrderWorkshopDetailsFromJson(
        Map<String, dynamic> json) =>
    OrderWorkshopDetails(
      title: json['title'] as String,
      artistNames: (json['artist_names'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      studioName: json['studio_name'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      uuid: json['uuid'] as String,
    );

Map<String, dynamic> _$OrderWorkshopDetailsToJson(
        OrderWorkshopDetails instance) =>
    <String, dynamic>{
      'title': instance.title,
      'artist_names': instance.artistNames,
      'studio_name': instance.studioName,
      'date': instance.date,
      'time': instance.time,
      'uuid': instance.uuid,
    };

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
      orderId: json['order_id'] as String,
      workshopUuid: json['workshop_uuid'] as String,
      workshopDetails: OrderWorkshopDetails.fromJson(
          json['workshop_details'] as Map<String, dynamic>),
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      status: $enumDecode(_$OrderStatusEnumMap, json['status']),
      paymentLinkUrl: json['payment_link_url'] as String?,
      qrCodeData: json['qr_code_data'] as String?,
      qrCodeGeneratedAt: json['qr_code_generated_at'] == null
          ? null
          : DateTime.parse(json['qr_code_generated_at'] as String),
      cashbackAmount: (json['cashback_amount'] as num?)?.toDouble(),
      rewardsRedeemed: (json['rewards_redeemed'] as num?)?.toDouble(),
      finalAmountPaid: (json['final_amount_paid'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
      'order_id': instance.orderId,
      'workshop_uuid': instance.workshopUuid,
      'workshop_details': instance.workshopDetails,
      'amount': instance.amount,
      'currency': instance.currency,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'payment_link_url': instance.paymentLinkUrl,
      'qr_code_data': instance.qrCodeData,
      'qr_code_generated_at': instance.qrCodeGeneratedAt?.toIso8601String(),
      'cashback_amount': instance.cashbackAmount,
      'rewards_redeemed': instance.rewardsRedeemed,
      'final_amount_paid': instance.finalAmountPaid,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$OrderStatusEnumMap = {
  OrderStatus.created: 'created',
  OrderStatus.paid: 'paid',
  OrderStatus.failed: 'failed',
  OrderStatus.expired: 'expired',
  OrderStatus.cancelled: 'cancelled',
};

CreatePaymentLinkRequest _$CreatePaymentLinkRequestFromJson(
        Map<String, dynamic> json) =>
    CreatePaymentLinkRequest(
      workshopUuid: json['workshop_uuid'] as String,
    );

Map<String, dynamic> _$CreatePaymentLinkRequestToJson(
        CreatePaymentLinkRequest instance) =>
    <String, dynamic>{
      'workshop_uuid': instance.workshopUuid,
    };

PaymentLinkResponse _$PaymentLinkResponseFromJson(Map<String, dynamic> json) =>
    PaymentLinkResponse(
      success: json['success'] as bool,
      isExisting: json['is_existing'] as bool,
      message: json['message'] as String,
      orderId: json['order_id'] as String,
      paymentLinkUrl: json['payment_link_url'] as String,
      paymentLinkId: json['payment_link_id'] as String?,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      workshopDetails: OrderWorkshopDetails.fromJson(
          json['workshop_details'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PaymentLinkResponseToJson(
        PaymentLinkResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'is_existing': instance.isExisting,
      'message': instance.message,
      'order_id': instance.orderId,
      'payment_link_url': instance.paymentLinkUrl,
      'payment_link_id': instance.paymentLinkId,
      'amount': instance.amount,
      'currency': instance.currency,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'workshop_details': instance.workshopDetails,
    };

CreatePaymentLinkResponse _$CreatePaymentLinkResponseFromJson(
        Map<String, dynamic> json) =>
    CreatePaymentLinkResponse(
      success: json['success'] as bool,
      orderId: json['order_id'] as String,
      paymentLinkUrl: json['payment_link_url'] as String,
      paymentLinkId: json['payment_link_id'] as String,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      workshopDetails: OrderWorkshopDetails.fromJson(
          json['workshop_details'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CreatePaymentLinkResponseToJson(
        CreatePaymentLinkResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'order_id': instance.orderId,
      'payment_link_url': instance.paymentLinkUrl,
      'payment_link_id': instance.paymentLinkId,
      'amount': instance.amount,
      'currency': instance.currency,
      'expires_at': instance.expiresAt.toIso8601String(),
      'workshop_details': instance.workshopDetails,
    };

ExistingPaymentResponse _$ExistingPaymentResponseFromJson(
        Map<String, dynamic> json) =>
    ExistingPaymentResponse(
      success: json['success'] as bool,
      error: json['error'] as String,
      message: json['message'] as String,
      existingOrder: json['existing_order'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$ExistingPaymentResponseToJson(
        ExistingPaymentResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'error': instance.error,
      'message': instance.message,
      'existing_order': instance.existingOrder,
    };

UserOrdersResponse _$UserOrdersResponseFromJson(Map<String, dynamic> json) =>
    UserOrdersResponse(
      success: json['success'] as bool,
      orders: (json['orders'] as List<dynamic>)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['total_count'] as num).toInt(),
      hasMore: json['has_more'] as bool,
    );

Map<String, dynamic> _$UserOrdersResponseToJson(UserOrdersResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'orders': instance.orders,
      'total_count': instance.totalCount,
      'has_more': instance.hasMore,
    };
