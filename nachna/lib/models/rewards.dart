import 'package:json_annotation/json_annotation.dart';

part 'rewards.g.dart';

enum RewardSourceEnum {
  @JsonValue('referral')
  referral,
  @JsonValue('cashback')
  cashback,
  @JsonValue('welcome_bonus')
  welcomeBonus,
  @JsonValue('special_promotion')
  specialPromotion,
  @JsonValue('workshop_completion')
  workshopCompletion,
  @JsonValue('admin_bonus')
  adminBonus,
}

enum RewardTransactionTypeEnum {
  @JsonValue('credit')
  credit,
  @JsonValue('debit')
  debit,
}

enum RewardTransactionStatusEnum {
  @JsonValue('pending')
  pending,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('cancelled')
  cancelled,
}

@JsonSerializable()
class RewardBalance {
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'total_balance')
  final double totalBalance;
  @JsonKey(name: 'available_balance')
  final double availableBalance;
  @JsonKey(name: 'lifetime_earned')
  final double lifetimeEarned;
  @JsonKey(name: 'lifetime_redeemed')
  final double lifetimeRedeemed;
  @JsonKey(name: 'redemption_cap_per_workshop')
  final double redemptionCapPerWorkshop;

  RewardBalance({
    required this.userId,
    required this.totalBalance,
    required this.availableBalance,
    required this.lifetimeEarned,
    required this.lifetimeRedeemed,
    required this.redemptionCapPerWorkshop,
  });

  factory RewardBalance.fromJson(Map<String, dynamic> json) => _$RewardBalanceFromJson(json);
  Map<String, dynamic> toJson() => _$RewardBalanceToJson(this);

  // Helper getters
  String get formattedTotalBalance => '₹${totalBalance.toStringAsFixed(0)}';
  String get formattedAvailableBalance => '₹${availableBalance.toStringAsFixed(0)}';
  String get formattedLifetimeEarned => '₹${lifetimeEarned.toStringAsFixed(0)}';
  String get formattedLifetimeRedeemed => '₹${lifetimeRedeemed.toStringAsFixed(0)}';
  String get formattedRedemptionCap => '₹${redemptionCapPerWorkshop.toStringAsFixed(0)}';
}

@JsonSerializable()
class RewardTransaction {
  @JsonKey(name: 'transaction_id')
  final String transactionId;
  @JsonKey(name: 'transaction_type')
  final RewardTransactionTypeEnum transactionType;
  final double amount;
  final String source;
  final String status;
  final String description;
  @JsonKey(name: 'reference_id')
  final String? referenceId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'processed_at')
  final DateTime? processedAt;

  RewardTransaction({
    required this.transactionId,
    required this.transactionType,
    required this.amount,
    required this.source,
    required this.status,
    required this.description,
    this.referenceId,
    required this.createdAt,
    this.processedAt,
  });

  factory RewardTransaction.fromJson(Map<String, dynamic> json) => _$RewardTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$RewardTransactionToJson(this);

  // Helper getters
  String get formattedAmount => '₹${amount.toStringAsFixed(0)}';
  String get formattedDate => '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  bool get isCredit => transactionType == RewardTransactionTypeEnum.credit;
  bool get isDebit => transactionType == RewardTransactionTypeEnum.debit;
  
  String get displayTitle {
    switch (source) {
      case 'referral':
        return 'Referral Bonus';
      case 'cashback':
        return isDebit ? 'Workshop Discount' : 'Cashback Earned';
      case 'welcome_bonus':
        return 'Welcome Bonus';
      case 'special_promotion':
        return 'Special Promotion';
      case 'workshop_completion':
        return 'Workshop Completion';
      case 'admin_bonus':
        return 'Admin Bonus';
      default:
        return 'Reward Transaction';
    }
  }
}

@JsonSerializable()
class RewardTransactionList {
  final List<RewardTransaction> transactions;
  @JsonKey(name: 'total_count')
  final int totalCount;
  final int page;
  @JsonKey(name: 'page_size')
  final int pageSize;

  RewardTransactionList({
    required this.transactions,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory RewardTransactionList.fromJson(Map<String, dynamic> json) => _$RewardTransactionListFromJson(json);
  Map<String, dynamic> toJson() => _$RewardTransactionListToJson(this);
}

@JsonSerializable()
class RewardSummary {
  final RewardBalance balance;
  @JsonKey(name: 'recent_transactions')
  final List<RewardTransaction> recentTransactions;
  @JsonKey(name: 'total_savings')
  final double totalSavings;
  @JsonKey(name: 'redemption_history_count')
  final int redemptionHistoryCount;

  RewardSummary({
    required this.balance,
    required this.recentTransactions,
    required this.totalSavings,
    required this.redemptionHistoryCount,
  });

  factory RewardSummary.fromJson(Map<String, dynamic> json) => _$RewardSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$RewardSummaryToJson(this);

  // Helper getters
  String get formattedTotalSavings => '₹${totalSavings.toStringAsFixed(0)}';
}

@JsonSerializable()
class WorkshopRedemptionInfo {
  @JsonKey(name: 'workshop_uuid')
  final String workshopUuid;
  @JsonKey(name: 'workshop_title')
  final String workshopTitle;
  @JsonKey(name: 'original_amount')
  final double originalAmount;
  @JsonKey(name: 'max_redeemable_points')
  final double maxRedeemablePoints;
  @JsonKey(name: 'max_discount_amount')
  final double maxDiscountAmount;
  @JsonKey(name: 'user_available_balance')
  final double userAvailableBalance;
  @JsonKey(name: 'recommended_redemption')
  final double recommendedRedemption;

  WorkshopRedemptionInfo({
    required this.workshopUuid,
    required this.workshopTitle,
    required this.originalAmount,
    required this.maxRedeemablePoints,
    required this.maxDiscountAmount,
    required this.userAvailableBalance,
    required this.recommendedRedemption,
  });

  factory WorkshopRedemptionInfo.fromJson(Map<String, dynamic> json) => _$WorkshopRedemptionInfoFromJson(json);
  Map<String, dynamic> toJson() => _$WorkshopRedemptionInfoToJson(this);

  // Helper getters
  String get formattedOriginalAmount => '₹${originalAmount.toStringAsFixed(0)}';
  String get formattedMaxDiscount => '₹${maxDiscountAmount.toStringAsFixed(0)}';
  String get formattedAvailableBalance => '₹${userAvailableBalance.toStringAsFixed(0)}';
  String get formattedRecommendedRedemption => '₹${recommendedRedemption.toStringAsFixed(0)}';
}

@JsonSerializable()
class RedemptionCalculation {
  @JsonKey(name: 'workshop_info')
  final WorkshopRedemptionInfo workshopInfo;
  @JsonKey(name: 'exchange_rate')
  final double exchangeRate;
  @JsonKey(name: 'can_redeem')
  final bool canRedeem;
  final String? message;

  RedemptionCalculation({
    required this.workshopInfo,
    required this.exchangeRate,
    required this.canRedeem,
    this.message,
  });

  factory RedemptionCalculation.fromJson(Map<String, dynamic> json) => _$RedemptionCalculationFromJson(json);
  Map<String, dynamic> toJson() => _$RedemptionCalculationToJson(this);
}

@JsonSerializable()
class RewardRedemptionRequest {
  @JsonKey(name: 'workshop_uuid')
  final String workshopUuid;
  @JsonKey(name: 'points_to_redeem')
  final double pointsToRedeem;
  @JsonKey(name: 'order_amount')
  final double orderAmount;

  RewardRedemptionRequest({
    required this.workshopUuid,
    required this.pointsToRedeem,
    required this.orderAmount,
  });

  factory RewardRedemptionRequest.fromJson(Map<String, dynamic> json) => _$RewardRedemptionRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RewardRedemptionRequestToJson(this);
}

@JsonSerializable()
class RewardRedemption {
  @JsonKey(name: 'redemption_id')
  final String redemptionId;
  @JsonKey(name: 'points_redeemed')
  final double pointsRedeemed;
  @JsonKey(name: 'discount_amount')
  final double discountAmount;
  @JsonKey(name: 'original_amount')
  final double originalAmount;
  @JsonKey(name: 'final_amount')
  final double finalAmount;
  @JsonKey(name: 'savings_percentage')
  final double savingsPercentage;
  final String status;

  RewardRedemption({
    required this.redemptionId,
    required this.pointsRedeemed,
    required this.discountAmount,
    required this.originalAmount,
    required this.finalAmount,
    required this.savingsPercentage,
    required this.status,
  });

  factory RewardRedemption.fromJson(Map<String, dynamic> json) => _$RewardRedemptionFromJson(json);
  Map<String, dynamic> toJson() => _$RewardRedemptionToJson(this);

  // Helper getters
  String get formattedPointsRedeemed => '${pointsRedeemed.toStringAsFixed(0)} pts';
  String get formattedDiscountAmount => '₹${discountAmount.toStringAsFixed(0)}';
  String get formattedOriginalAmount => '₹${originalAmount.toStringAsFixed(0)}';
  String get formattedFinalAmount => '₹${finalAmount.toStringAsFixed(0)}';
  String get formattedSavingsPercentage => '${savingsPercentage.toStringAsFixed(1)}%';
}
