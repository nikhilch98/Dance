import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive_utils.dart';
import '../widgets/qr_code_display.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final OrderService _orderService = OrderService();
  late Future<UserOrdersResponse> _ordersFuture;

  // Filter states
  List<OrderStatus>? _selectedStatuses;
  String _currentFilter = 'All Orders';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
    _loadOrders();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = _orderService.getUserOrders(status: _selectedStatuses);
    });
  }

  void _applyFilter(String filterName, List<OrderStatus>? statuses) {
    setState(() {
      _currentFilter = filterName;
      _selectedStatuses = statuses;
    });
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;

        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A0F),
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Custom App Bar
                  SliverAppBar(
                    expandedHeight: ResponsiveUtils.isSmallScreen(context) ? 100 : 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: ResponsiveUtils.iconMedium(context),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                        ),
                        child: ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: ResponsiveUtils.paddingLarge(context),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: ResponsiveUtils.paddingSmall(context),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.receipt_long_rounded,
                                        color: Colors.white,
                                        size: ResponsiveUtils.iconMedium(context),
                                      ),
                                    ),
                                    SizedBox(width: ResponsiveUtils.spacingLarge(context)),
                                    Text(
                                      'My Orders',
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils.h2(context),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Filter Chips
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacingLarge(context),
                        vertical: ResponsiveUtils.spacingMedium(context),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip('All Orders', null, const Color(0xFF3B82F6)),
                            SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                            _buildFilterChip('Pending', [OrderStatus.created], const Color(0xFFFF8C00)),
                            SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                            _buildFilterChip('Completed', [OrderStatus.paid], const Color(0xFF10B981)),
                            SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                            _buildFilterChip('Failed/Expired', [OrderStatus.failed, OrderStatus.expired], const Color(0xFFEF4444)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Orders Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: ResponsiveUtils.paddingLarge(context),
                      child: FutureBuilder<UserOrdersResponse>(
                        future: _ordersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildLoadingState();
                          } else if (snapshot.hasError) {
                            return _buildErrorState(snapshot.error.toString());
                          } else if (!snapshot.hasData || snapshot.data!.orders.isEmpty) {
                            return _buildEmptyState();
                          } else {
                            return _buildOrdersList(snapshot.data!.orders);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, List<OrderStatus>? statuses, Color color) {
    final isSelected = _currentFilter == label;
    return GestureDetector(
      onTap: () => _applyFilter(label, statuses),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacingMedium(context),
          vertical: ResponsiveUtils.spacingSmall(context),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(isSelected ? 0.3 : 0.1),
              color.withOpacity(isSelected ? 0.2 : 0.05),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(isSelected ? 0.6 : 0.3),
            width: ResponsiveUtils.borderWidthThin(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white70,
            fontSize: ResponsiveUtils.micro(context),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Container(
          padding: ResponsiveUtils.paddingXLarge(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                strokeWidth: ResponsiveUtils.borderWidthMedium(context),
              ),
              SizedBox(height: ResponsiveUtils.spacingMedium(context)),
              Text(
                'Loading your orders...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: ResponsiveUtils.body2(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: ResponsiveUtils.paddingXLarge(context),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
          gradient: LinearGradient(
            colors: [
              Colors.red.withOpacity(0.1),
              Colors.red.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: ResponsiveUtils.iconXLarge(context),
              color: Colors.redAccent,
            ),
            SizedBox(height: ResponsiveUtils.spacingMedium(context)),
            Text(
              'Error loading orders',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: ResponsiveUtils.body1(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacingSmall(context)),
            Text(
              error,
              style: TextStyle(
                color: Colors.white70,
                fontSize: ResponsiveUtils.body2(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.spacingMedium(context)),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: ResponsiveUtils.paddingXLarge(context),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: ResponsiveUtils.iconXLarge(context) * 1.5,
              color: Colors.white.withOpacity(0.5),
            ),
            SizedBox(height: ResponsiveUtils.spacingLarge(context)),
            Text(
              _currentFilter == 'All Orders' ? 'No orders yet' : 'No $_currentFilter found',
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.body1(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacingSmall(context)),
            Text(
              _currentFilter == 'All Orders' 
                  ? 'When you register for workshops, your orders will appear here.'
                  : 'Try selecting a different filter to see more orders.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: ResponsiveUtils.body2(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order, index);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    return GestureDetector(
      onTap: () => _handleOrderTap(order),
      child: Container(
        margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingMedium(context)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: ResponsiveUtils.borderWidthThin(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: ResponsiveUtils.paddingLarge(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Header Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.workshopDetails.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveUtils.body1(context),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
                          Text(
                            'Order ID: ${order.formattedOrderId}',
                            style: TextStyle(
                              color: const Color(0xFF00D4FF),
                              fontSize: ResponsiveUtils.micro(context),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacingSmall(context),
                        vertical: ResponsiveUtils.spacingXSmall(context),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                        color: order.statusColor.withOpacity(0.2),
                        border: Border.all(
                          color: order.statusColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        order.statusText,
                        style: TextStyle(
                          color: order.statusColor,
                          fontSize: ResponsiveUtils.micro(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: ResponsiveUtils.spacingMedium(context)),

                // Workshop Details
                _buildDetailRow(Icons.person_rounded, 'Artists', order.workshopDetails.artistNames.join(', ')),
                _buildDetailRow(Icons.business_rounded, 'Studio', order.workshopDetails.studioName),
                _buildDetailRow(Icons.calendar_today_rounded, 'Date', order.workshopDetails.date),
                _buildDetailRow(Icons.access_time_rounded, 'Time', order.workshopDetails.time),

                SizedBox(height: ResponsiveUtils.spacingMedium(context)),

                // Amount and Action Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: ResponsiveUtils.micro(context),
                            ),
                          ),
                          Text(
                            order.formattedAmount,
                            style: TextStyle(
                              color: const Color(0xFF00D4FF),
                              fontSize: ResponsiveUtils.body1(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.status == OrderStatus.created && order.paymentLinkUrl != null)
                      _buildPayNowButton(order),
                  ],
                ),

                // Reward Information Section (for paid orders)
                if (order.status == OrderStatus.paid && (order.hasCashback || order.hasRewardsRedeemed)) ...[
                  SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                  _buildRewardSection(order),
                ],

                SizedBox(height: ResponsiveUtils.spacingSmall(context)),

                // Order Date
                Text(
                  'Ordered on ${_formatDateTime(order.createdAt)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: ResponsiveUtils.micro(context),
                  ),
                ),
                
                // QR Code indicator for paid orders
                if (order.status == OrderStatus.paid) ...[
                  SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                  Row(
                    children: [
                      Icon(
                        order.hasQRCode ? Icons.qr_code : Icons.hourglass_top,
                        color: order.hasQRCode ? const Color(0xFF10B981) : Colors.orange,
                        size: ResponsiveUtils.iconXSmall(context),
                      ),
                      SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
                      Expanded(
                        child: Text(
                          order.hasQRCode 
                            ? 'Tap to view QR code' 
                            : 'QR code generating...',
                          style: TextStyle(
                            color: order.hasQRCode 
                              ? const Color(0xFF10B981)
                              : Colors.orange,
                            fontSize: ResponsiveUtils.micro(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (order.hasQRCode)
                        Icon(
                          Icons.touch_app,
                          color: const Color(0xFF10B981).withOpacity(0.6),
                          size: ResponsiveUtils.iconXSmall(context),
                        ),
                    ],
                  ),
                ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.spacingXSmall(context)),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.7),
            size: ResponsiveUtils.iconXSmall(context),
          ),
          SizedBox(width: ResponsiveUtils.spacingSmall(context)),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: ResponsiveUtils.micro(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayNowButton(Order order) {
    return GestureDetector(
      onTap: () => _launchPaymentUrl(order.paymentLinkUrl!),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacingMedium(context),
          vertical: ResponsiveUtils.spacingSmall(context),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          'Pay Now',
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveUtils.micro(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRewardSection(Order order) {
    return Container(
      padding: ResponsiveUtils.paddingMedium(context),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.15),
            const Color(0xFF059669).withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.stars_rounded,
                color: const Color(0xFF10B981),
                size: ResponsiveUtils.iconSmall(context),
              ),
              SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
              Text(
                'Rewards Summary',
                style: TextStyle(
                  color: const Color(0xFF10B981),
                  fontSize: ResponsiveUtils.micro(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacingSmall(context)),
          
          // Show cashback earned
          if (order.hasCashback) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cashback Earned (15%)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: ResponsiveUtils.micro(context),
                  ),
                ),
                Text(
                  '+ ${order.formattedCashbackAmount}',
                  style: TextStyle(
                    color: const Color(0xFF10B981),
                    fontSize: ResponsiveUtils.micro(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          
          // Show rewards redeemed if any
          if (order.hasRewardsRedeemed) ...[
            if (order.hasCashback) SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rewards Redeemed',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: ResponsiveUtils.micro(context),
                  ),
                ),
                Text(
                  '- ${order.formattedRewardsRedeemed}',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: ResponsiveUtils.micro(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          
          // Show final amount paid if different from original
          if (order.hasFinalAmountPaid && order.hasRewardsRedeemed) ...[
            SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
            Divider(color: Colors.white.withOpacity(0.2), height: 1),
            SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Final Amount Paid',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveUtils.micro(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  order.formattedFinalAmountPaid,
                  style: TextStyle(
                    color: const Color(0xFF00D4FF),
                    fontSize: ResponsiveUtils.micro(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _launchPaymentUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not open payment link');
      }
    } catch (e) {
      _showErrorSnackBar('Could not open payment link');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $amPm';
  }

  void _handleOrderTap(Order order) {
    if (order.status == OrderStatus.paid) {
      if (order.hasQRCode) {
        // Show QR code in fullscreen
        QRCodeDisplay.showFullscreen(context, order);
      } else {
        // Show message that QR code is being generated
        _showInfoSnackBar('Your QR code is being generated. Please check back in a few minutes.');
      }
    } else {
      // For non-paid orders, show order details or payment option
      if (order.paymentLinkUrl != null) {
        _showPaymentPrompt(order);
      } else {
        _showInfoSnackBar('Order details: ${order.statusText}');
      }
    }
  }

  void _showPaymentPrompt(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Complete Payment',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Complete your payment for ${order.workshopDetails.title} to receive your QR code.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchPaymentUrl(order.paymentLinkUrl!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
