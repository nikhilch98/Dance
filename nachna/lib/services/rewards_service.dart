import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/rewards.dart';
import '../services/auth_service.dart';

class RewardsService {
  static const String baseUrl = 'https://nachna.com';
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Get user's reward balance information
  static Future<RewardBalance> getRewardBalance() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/rewards/balance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(requestTimeout);

      print('[RewardsService] Get balance response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return RewardBalance.fromJson(responseData);
      } else {
        throw Exception('Failed to get reward balance: ${response.statusCode}');
      }
    } catch (e) {
      print('[RewardsService] Error getting reward balance: $e');
      throw Exception('Failed to get reward balance: $e');
    }
  }

  /// Get user's reward transactions with pagination
  static Future<RewardTransactionList> getRewardTransactions({
    int page = 1,
    int pageSize = 20,
    RewardTransactionTypeEnum? transactionType,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      String url = '$baseUrl/api/rewards/transactions?page=$page&page_size=$pageSize';
      if (transactionType != null) {
        url += '&transaction_type=${transactionType.toString().split('.').last}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(requestTimeout);

      print('[RewardsService] Get transactions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return RewardTransactionList.fromJson(responseData);
      } else {
        throw Exception('Failed to get reward transactions: ${response.statusCode}');
      }
    } catch (e) {
      print('[RewardsService] Error getting reward transactions: $e');
      throw Exception('Failed to get reward transactions: $e');
    }
  }

  /// Get comprehensive reward summary for rewards center
  static Future<RewardSummary> getRewardSummary() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/rewards/summary'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(requestTimeout);

      print('[RewardsService] Get summary response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return RewardSummary.fromJson(responseData);
      } else {
        throw Exception('Failed to get reward summary: ${response.statusCode}');
      }
    } catch (e) {
      print('[RewardsService] Error getting reward summary: $e');
      throw Exception('Failed to get reward summary: $e');
    }
  }

  /// Calculate available redemption for a workshop
  static Future<RedemptionCalculation> calculateRedemption({
    required String workshopUuid,
    required double workshopAmount,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final requestBody = {
        'workshop_uuid': workshopUuid,
        'workshop_amount': workshopAmount,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/rewards/calculate-redemption'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      ).timeout(requestTimeout);

      print('[RewardsService] Calculate redemption response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return RedemptionCalculation.fromJson(responseData);
      } else {
        throw Exception('Failed to calculate redemption: ${response.statusCode}');
      }
    } catch (e) {
      print('[RewardsService] Error calculating redemption: $e');
      throw Exception('Failed to calculate redemption: $e');
    }
  }

  /// Redeem reward points for workshop booking discount
  static Future<RewardRedemption> redeemRewards({
    required String workshopUuid,
    required double pointsToRedeem,
    required double orderAmount,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final requestBody = {
        'workshop_uuid': workshopUuid,
        'points_to_redeem': pointsToRedeem,
        'order_amount': orderAmount,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/rewards/redeem'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      ).timeout(requestTimeout);

      print('[RewardsService] Redeem rewards response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return RewardRedemption.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to redeem rewards');
      }
    } catch (e) {
      print('[RewardsService] Error redeeming rewards: $e');
      throw Exception('Failed to redeem rewards: $e');
    }
  }

  /// Get user's reward redemption history
  static Future<Map<String, dynamic>> getRedemptionHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/rewards/redemptions?page=$page&page_size=$pageSize'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(requestTimeout);

      print('[RewardsService] Get redemption history response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get redemption history: ${response.statusCode}');
      }
    } catch (e) {
      print('[RewardsService] Error getting redemption history: $e');
      throw Exception('Failed to get redemption history: $e');
    }
  }

  /// Calculate final amount after applying rewards discount
  static Map<String, dynamic> calculateFinalAmount({
    required double originalAmount,
    required double pointsToRedeem,
    double exchangeRate = 1.0,
  }) {
    final discountAmount = pointsToRedeem * exchangeRate;
    final finalAmount = (originalAmount - discountAmount).clamp(0.0, originalAmount);
    final savingsPercentage = originalAmount > 0 ? (discountAmount / originalAmount) * 100 : 0.0;

    return {
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'savings_percentage': savingsPercentage,
      'formatted_discount': '₹${discountAmount.toStringAsFixed(0)}',
      'formatted_final_amount': '₹${finalAmount.toStringAsFixed(0)}',
      'formatted_savings': '${savingsPercentage.toStringAsFixed(1)}%',
    };
  }

  /// Validate redemption amount
  static bool validateRedemption({
    required double pointsToRedeem,
    required double availableBalance,
    required double maxRedeemable,
  }) {
    return pointsToRedeem > 0 && 
           pointsToRedeem <= availableBalance && 
           pointsToRedeem <= maxRedeemable;
  }

  /// Format points as display string
  static String formatPoints(double points) {
    if (points >= 1000) {
      return '${(points / 1000).toStringAsFixed(1)}K pts';
    }
    return '${points.toStringAsFixed(0)} pts';
  }

  /// Format currency amount
  static String formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  /// Get reward status color based on transaction type
  static String getTransactionStatusColor(RewardTransactionTypeEnum type) {
    switch (type) {
      case RewardTransactionTypeEnum.credit:
        return '#10B981'; // Green
      case RewardTransactionTypeEnum.debit:
        return '#F59E0B'; // Orange
    }
  }

  /// Get reward source icon based on source type
  static String getSourceIcon(String source) {
    switch (source) {
      case 'referral':
        return '👥';
      case 'cashback':
        return '💰';
      case 'welcome_bonus':
        return '🎉';
      case 'special_promotion':
        return '🎁';
      case 'workshop_completion':
        return '🏆';
      case 'admin_bonus':
        return '⭐';
      default:
        return '💎';
    }
  }
}
