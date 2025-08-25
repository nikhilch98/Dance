import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order.g.dart';

/// Enum for order status
enum OrderStatus {
  @JsonValue('created')
  created,
  @JsonValue('paid')
  paid,
  @JsonValue('failed')
  failed,
  @JsonValue('expired')
  expired,
  @JsonValue('cancelled')
  cancelled,
}

/// Workshop details embedded in order
@JsonSerializable()
class OrderWorkshopDetails {
  final String title;
  @JsonKey(name: 'artist_names')
  final List<String> artistNames;
  @JsonKey(name: 'studio_name')
  final String studioName;
  final String date;
  final String time;
  final String uuid;

  OrderWorkshopDetails({
    required this.title,
    required this.artistNames,
    required this.studioName,
    required this.date,
    required this.time,
    required this.uuid,
  });

  factory OrderWorkshopDetails.fromJson(Map<String, dynamic> json) => _$OrderWorkshopDetailsFromJson(json);
  Map<String, dynamic> toJson() => _$OrderWorkshopDetailsToJson(this);
}

/// Order model for API responses
@JsonSerializable()
class Order {
  @JsonKey(name: 'order_id')
  final String orderId;
  @JsonKey(name: 'workshop_uuid')
  final String workshopUuid;
  @JsonKey(name: 'workshop_details')
  final OrderWorkshopDetails workshopDetails;
  final int amount; // Amount in paise
  final String currency;
  final OrderStatus status;
  @JsonKey(name: 'payment_link_url')
  final String? paymentLinkUrl;
  @JsonKey(name: 'qr_code_data')
  final String? qrCodeData;
  @JsonKey(name: 'qr_code_generated_at')
  final DateTime? qrCodeGeneratedAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Order({
    required this.orderId,
    required this.workshopUuid,
    required this.workshopDetails,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentLinkUrl,
    this.qrCodeData,
    this.qrCodeGeneratedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);

  // Helper getters for UI
  String get formattedAmount => '₹${(amount / 100).toStringAsFixed(2)}';
  
  // Format order ID for user-friendly display
  String get formattedOrderId {
    // Show full order ID in a readable format: NACHNA-XXXXXXXX (last 8 chars)
    if (orderId.length > 8) {
      final lastEight = orderId.substring(orderId.length - 8).toUpperCase();
      return 'NACHNA-$lastEight';
    }
    return orderId.toUpperCase();
  }
  
  // Short order ID for compact display
  String get shortOrderId {
    if (orderId.length > 8) {
      return orderId.substring(orderId.length - 8).toUpperCase();
    }
    return orderId.toUpperCase();
  }
  
  // QR Code availability check
  bool get hasQRCode => qrCodeData != null && qrCodeData!.isNotEmpty;
  
  // QR Code status text
  String get qrCodeStatus {
    if (status != OrderStatus.paid) {
      return 'QR Available After Payment';
    } else if (hasQRCode) {
      return 'QR Code Ready';
    } else {
      return 'QR Code Generating...';
    }
  }
  
  // QR Code generated time formatted
  String get qrCodeGeneratedTime {
    if (qrCodeGeneratedAt == null) return 'Not generated';
    
    final now = DateTime.now();
    final diff = now.difference(qrCodeGeneratedAt!);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }
  
  String get statusText {
    switch (status) {
      case OrderStatus.created:
        return 'Payment Pending';
      case OrderStatus.paid:
        return 'Completed';
      case OrderStatus.failed:
        return 'Failed';
      case OrderStatus.expired:
        return 'Expired';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
  
  Color get statusColor {
    switch (status) {
      case OrderStatus.created:
        return const Color(0xFFFF8C00); // Orange
      case OrderStatus.paid:
        return const Color(0xFF10B981); // Green
      case OrderStatus.failed:
        return const Color(0xFFEF4444); // Red
      case OrderStatus.expired:
        return const Color(0xFF6B7280); // Gray
      case OrderStatus.cancelled:
        return const Color(0xFF6B7280); // Gray
    }
  }
}

/// Request model for creating payment link
@JsonSerializable()
class CreatePaymentLinkRequest {
  @JsonKey(name: 'workshop_uuid')
  final String workshopUuid;

  CreatePaymentLinkRequest({required this.workshopUuid});

  factory CreatePaymentLinkRequest.fromJson(Map<String, dynamic> json) => _$CreatePaymentLinkRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreatePaymentLinkRequestToJson(this);
}

/// Unified response model for payment link creation (new or existing)
@JsonSerializable()
class PaymentLinkResponse {
  final bool success;
  @JsonKey(name: 'is_existing')
  final bool isExisting;
  final String message;
  @JsonKey(name: 'order_id')
  final String orderId;
  @JsonKey(name: 'payment_link_url')
  final String paymentLinkUrl;
  @JsonKey(name: 'payment_link_id')
  final String? paymentLinkId;
  final int amount;
  final String currency;
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @JsonKey(name: 'workshop_details')
  final OrderWorkshopDetails workshopDetails;

  PaymentLinkResponse({
    required this.success,
    required this.isExisting,
    required this.message,
    required this.orderId,
    required this.paymentLinkUrl,
    this.paymentLinkId,
    required this.amount,
    required this.currency,
    this.expiresAt,
    required this.workshopDetails,
  });

  factory PaymentLinkResponse.fromJson(Map<String, dynamic> json) => _$PaymentLinkResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentLinkResponseToJson(this);

  // Helper getters for UI
  String get formattedOrderId {
    // Show order ID in a readable format: NACHNA-XXXXXXXX (last 8 chars)
    if (orderId.length > 8) {
      final lastEight = orderId.substring(orderId.length - 8).toUpperCase();
      return 'NACHNA-$lastEight';
    }
    return orderId.toUpperCase();
  }

  String get formattedAmount => '₹${(amount / 100).toStringAsFixed(2)}';
}

/// Response model for successful payment link creation (kept for backward compatibility)
@JsonSerializable()
class CreatePaymentLinkResponse {
  final bool success;
  @JsonKey(name: 'order_id')
  final String orderId;
  @JsonKey(name: 'payment_link_url')
  final String paymentLinkUrl;
  @JsonKey(name: 'payment_link_id')
  final String paymentLinkId;
  final int amount;
  final String currency;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @JsonKey(name: 'workshop_details')
  final OrderWorkshopDetails workshopDetails;

  CreatePaymentLinkResponse({
    required this.success,
    required this.orderId,
    required this.paymentLinkUrl,
    required this.paymentLinkId,
    required this.amount,
    required this.currency,
    required this.expiresAt,
    required this.workshopDetails,
  });

  factory CreatePaymentLinkResponse.fromJson(Map<String, dynamic> json) => _$CreatePaymentLinkResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CreatePaymentLinkResponseToJson(this);
}

/// Response model for existing payment link
@JsonSerializable()
class ExistingPaymentResponse {
  final bool success;
  final String error;
  final String message;
  @JsonKey(name: 'existing_order')
  final Map<String, dynamic> existingOrder;

  ExistingPaymentResponse({
    required this.success,
    required this.error,
    required this.message,
    required this.existingOrder,
  });

  factory ExistingPaymentResponse.fromJson(Map<String, dynamic> json) => _$ExistingPaymentResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ExistingPaymentResponseToJson(this);

  // Helper getters for existing order
  String? get existingOrderId => existingOrder['order_id'] as String?;
  String? get existingPaymentLinkUrl => existingOrder['payment_link_url'] as String?;
  DateTime? get existingExpiresAt {
    final expiresAtStr = existingOrder['expires_at'] as String?;
    return expiresAtStr != null ? DateTime.parse(expiresAtStr) : null;
  }
}

/// Response model for user orders list
@JsonSerializable()
class UserOrdersResponse {
  final bool success;
  final List<Order> orders;
  @JsonKey(name: 'total_count')
  final int totalCount;
  @JsonKey(name: 'has_more')
  final bool hasMore;

  UserOrdersResponse({
    required this.success,
    required this.orders,
    required this.totalCount,
    required this.hasMore,
  });

  factory UserOrdersResponse.fromJson(Map<String, dynamic> json) => _$UserOrdersResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UserOrdersResponseToJson(this);
}

/// Payment link creation result (simplified with unified response)
class PaymentLinkResult {
  final bool isSuccess;
  final PaymentLinkResponse? response;
  final String? errorMessage;

  PaymentLinkResult.success(this.response)
      : isSuccess = true,
        errorMessage = null;

  PaymentLinkResult.error(this.errorMessage)
      : isSuccess = false,
        response = null;

  // Helper getters for easier access
  String? get paymentUrl => response?.paymentLinkUrl;
  bool get isExisting => response?.isExisting ?? false;
  String? get message => response?.message;
  
  // Backward compatibility getters
  PaymentLinkResponse? get successResponse => response;
  ExistingPaymentResponse? get existingResponse => null; // No longer used
}
