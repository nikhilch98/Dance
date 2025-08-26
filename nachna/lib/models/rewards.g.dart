// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rewards.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RewardBalance _$RewardBalanceFromJson(Map<String, dynamic> json) =>
    RewardBalance(
      userId: json['user_id'] as String,
      totalBalance: (json['total_balance'] as num).toDouble(),
      availableBalance: (json['available_balance'] as num).toDouble(),
      lifetimeEarned: (json['lifetime_earned'] as num).toDouble(),
      lifetimeRedeemed: (json['lifetime_redeemed'] as num).toDouble(),
      redemptionCapPerWorkshop:
          (json['redemption_cap_per_workshop'] as num).toDouble(),
    );

Map<String, dynamic> _$RewardBalanceToJson(RewardBalance instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'total_balance': instance.totalBalance,
      'available_balance': instance.availableBalance,
      'lifetime_earned': instance.lifetimeEarned,
      'lifetime_redeemed': instance.lifetimeRedeemed,
      'redemption_cap_per_workshop': instance.redemptionCapPerWorkshop,
    };

RewardTransaction _$RewardTransactionFromJson(Map<String, dynamic> json) =>
    RewardTransaction(
      transactionId: json['transaction_id'] as String,
      transactionType: $enumDecode(
          _$RewardTransactionTypeEnumEnumMap, json['transaction_type']),
      amount: (json['amount'] as num).toDouble(),
      source: json['source'] as String,
      status: json['status'] as String,
      description: json['description'] as String,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      processedAt: json['processed_at'] == null
          ? null
          : DateTime.parse(json['processed_at'] as String),
    );

Map<String, dynamic> _$RewardTransactionToJson(RewardTransaction instance) =>
    <String, dynamic>{
      'transaction_id': instance.transactionId,
      'transaction_type':
          _$RewardTransactionTypeEnumEnumMap[instance.transactionType]!,
      'amount': instance.amount,
      'source': instance.source,
      'status': instance.status,
      'description': instance.description,
      'reference_id': instance.referenceId,
      'created_at': instance.createdAt.toIso8601String(),
      'processed_at': instance.processedAt?.toIso8601String(),
    };

const _$RewardTransactionTypeEnumEnumMap = {
  RewardTransactionTypeEnum.credit: 'credit',
  RewardTransactionTypeEnum.debit: 'debit',
};

RewardTransactionList _$RewardTransactionListFromJson(
        Map<String, dynamic> json) =>
    RewardTransactionList(
      transactions: (json['transactions'] as List<dynamic>)
          .map((e) => RewardTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['total_count'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
    );

Map<String, dynamic> _$RewardTransactionListToJson(
        RewardTransactionList instance) =>
    <String, dynamic>{
      'transactions': instance.transactions,
      'total_count': instance.totalCount,
      'page': instance.page,
      'page_size': instance.pageSize,
    };

RewardSummary _$RewardSummaryFromJson(Map<String, dynamic> json) =>
    RewardSummary(
      balance: RewardBalance.fromJson(json['balance'] as Map<String, dynamic>),
      recentTransactions: (json['recent_transactions'] as List<dynamic>)
          .map((e) => RewardTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalSavings: (json['total_savings'] as num).toDouble(),
      redemptionHistoryCount: (json['redemption_history_count'] as num).toInt(),
    );

Map<String, dynamic> _$RewardSummaryToJson(RewardSummary instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'recent_transactions': instance.recentTransactions,
      'total_savings': instance.totalSavings,
      'redemption_history_count': instance.redemptionHistoryCount,
    };

WorkshopRedemptionInfo _$WorkshopRedemptionInfoFromJson(
        Map<String, dynamic> json) =>
    WorkshopRedemptionInfo(
      workshopUuid: json['workshop_uuid'] as String,
      workshopTitle: json['workshop_title'] as String,
      originalAmount: (json['original_amount'] as num).toDouble(),
      maxRedeemablePoints: (json['max_redeemable_points'] as num).toDouble(),
      maxDiscountAmount: (json['max_discount_amount'] as num).toDouble(),
      userAvailableBalance: (json['user_available_balance'] as num).toDouble(),
      recommendedRedemption: (json['recommended_redemption'] as num).toDouble(),
    );

Map<String, dynamic> _$WorkshopRedemptionInfoToJson(
        WorkshopRedemptionInfo instance) =>
    <String, dynamic>{
      'workshop_uuid': instance.workshopUuid,
      'workshop_title': instance.workshopTitle,
      'original_amount': instance.originalAmount,
      'max_redeemable_points': instance.maxRedeemablePoints,
      'max_discount_amount': instance.maxDiscountAmount,
      'user_available_balance': instance.userAvailableBalance,
      'recommended_redemption': instance.recommendedRedemption,
    };

RedemptionCalculation _$RedemptionCalculationFromJson(
        Map<String, dynamic> json) =>
    RedemptionCalculation(
      workshopInfo: WorkshopRedemptionInfo.fromJson(
          json['workshop_info'] as Map<String, dynamic>),
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      canRedeem: json['can_redeem'] as bool,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$RedemptionCalculationToJson(
        RedemptionCalculation instance) =>
    <String, dynamic>{
      'workshop_info': instance.workshopInfo,
      'exchange_rate': instance.exchangeRate,
      'can_redeem': instance.canRedeem,
      'message': instance.message,
    };

RewardRedemptionRequest _$RewardRedemptionRequestFromJson(
        Map<String, dynamic> json) =>
    RewardRedemptionRequest(
      workshopUuid: json['workshop_uuid'] as String,
      pointsToRedeem: (json['points_to_redeem'] as num).toDouble(),
      orderAmount: (json['order_amount'] as num).toDouble(),
    );

Map<String, dynamic> _$RewardRedemptionRequestToJson(
        RewardRedemptionRequest instance) =>
    <String, dynamic>{
      'workshop_uuid': instance.workshopUuid,
      'points_to_redeem': instance.pointsToRedeem,
      'order_amount': instance.orderAmount,
    };

RewardRedemption _$RewardRedemptionFromJson(Map<String, dynamic> json) =>
    RewardRedemption(
      redemptionId: json['redemption_id'] as String,
      pointsRedeemed: (json['points_redeemed'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num).toDouble(),
      originalAmount: (json['original_amount'] as num).toDouble(),
      finalAmount: (json['final_amount'] as num).toDouble(),
      savingsPercentage: (json['savings_percentage'] as num).toDouble(),
      status: json['status'] as String,
    );

Map<String, dynamic> _$RewardRedemptionToJson(RewardRedemption instance) =>
    <String, dynamic>{
      'redemption_id': instance.redemptionId,
      'points_redeemed': instance.pointsRedeemed,
      'discount_amount': instance.discountAmount,
      'original_amount': instance.originalAmount,
      'final_amount': instance.finalAmount,
      'savings_percentage': instance.savingsPercentage,
      'status': instance.status,
    };
