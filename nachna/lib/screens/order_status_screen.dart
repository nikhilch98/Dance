import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

import '../models/order.dart';
import '../services/order_service.dart';
import '../utils/responsive_utils.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;
  final String workshopTitle;
  final String amount;

  const OrderStatusScreen({
    Key? key,
    required this.orderId,
    required this.workshopTitle,
    required this.amount,
  }) : super(key: key);

  @override
  _OrderStatusScreenState createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen>
    with TickerProviderStateMixin {
  Timer? _statusTimer;
  Order? _currentOrder;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startStatusPolling();
  }

  void _setupAnimations() {
    // Pulse animation for pending state
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Success animation for completed state
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _successAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  void _startStatusPolling() {
    _checkOrderStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkOrderStatus();
    });
  }

  Future<void> _checkOrderStatus() async {
    try {
      print('[OrderStatus] Checking status for order: ${widget.orderId}');
      
      // Use the efficient single order status API
      final order = await OrderService().getOrderStatus(widget.orderId);
      
      setState(() {
        _currentOrder = order;
        _isLoading = false;
        _errorMessage = null;
      });

      print('[OrderStatus] Order status: ${order.status.name}');
      print('[OrderStatus] Status updated via internal database (webhook-driven)');

      // If order is paid, stop polling and trigger success animation
      if (order.status == OrderStatus.paid) {
        _statusTimer?.cancel();
        _pulseController.stop();
        _successController.forward();
        print('[OrderStatus] Payment confirmed! Stopping status polling.');
      }
    } catch (e) {
      print('[OrderStatus] Error checking order status: $e');
      
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: Padding(
            padding: ResponsiveUtils.paddingLarge(context),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildContent(),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundGradient() {
    final isPaid = _currentOrder?.status == OrderStatus.paid;
    
    if (isPaid) {
      // Green gradient for success
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A1A0F),
            Color(0xFF1A2E1A),
            Color(0xFF16342E),
            Color(0xFF0F4640),
          ],
        ),
      );
    } else {
      // Orange gradient for pending
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A0F0A),
            Color(0xFF2E1A1A),
            Color(0xFF342916),
            Color(0xFF46340F),
          ],
        ),
      );
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Order Status',
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveUtils.h2(context),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading && _currentOrder == null) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_currentOrder != null) {
      return _buildOrderStatusContent();
    }

    return _buildLoadingState();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading order details...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: ResponsiveUtils.body1(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.withOpacity(0.8),
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            'Unable to load order',
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveUtils.h3(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Please try again',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: ResponsiveUtils.body2(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _isLoading = true;
              });
              _checkOrderStatus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusContent() {
    final order = _currentOrder!;
    final isPaid = order.status == OrderStatus.paid;

    return Column(
      children: [
        const SizedBox(height: 40),
        _buildStatusIcon(isPaid),
        const SizedBox(height: 32),
        _buildStatusText(isPaid),
        const SizedBox(height: 40),
        _buildOrderDetailsCard(order),
        const Spacer(),
        if (isPaid) _buildSuccessActions(),
      ],
    );
  }

  Widget _buildStatusIcon(bool isPaid) {
    if (isPaid) {
      return ScaleTransition(
        scale: _successAnimation,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.4),
                offset: const Offset(0, 8),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 60,
          ),
        ),
      );
    } else {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFFF6B00)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8C00).withOpacity(0.4),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildStatusText(bool isPaid) {
    if (isPaid) {
      return Column(
        children: [
          Text(
            'Payment Successful!',
            style: TextStyle(
              color: const Color(0xFF10B981),
              fontSize: ResponsiveUtils.h2(context),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your workshop registration is confirmed',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: ResponsiveUtils.body1(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Text(
            'Processing Payment...',
            style: TextStyle(
              color: const Color(0xFFFF8C00),
              fontSize: ResponsiveUtils.h2(context),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we confirm your payment',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: ResponsiveUtils.body1(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Checking status every 5 seconds...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: ResponsiveUtils.micro(context),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildOrderDetailsCard(Order order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveUtils.h3(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Order ID', order.formattedOrderId),
              const SizedBox(height: 12),
              _buildDetailRow('Workshop', order.workshopDetails.title),
              const SizedBox(height: 12),
              _buildDetailRow('Amount', order.formattedAmount),
              const SizedBox(height: 12),
              _buildDetailRow('Status', order.statusText, isStatus: true),
              if (order.workshopDetails.date.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow('Date', order.workshopDetails.date),
              ],
              if (order.workshopDetails.time.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow('Time', order.workshopDetails.time),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    Color valueColor = Colors.white;
    if (isStatus && _currentOrder != null) {
      valueColor = _currentOrder!.statusColor;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: ResponsiveUtils.body2(context),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: ResponsiveUtils.body2(context),
              fontWeight: isStatus ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/orders');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: const Color(0xFF10B981).withOpacity(0.3),
            ),
            child: const Text(
              'View All Orders',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF10B981)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Back to Home',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_currentOrder?.status != OrderStatus.paid) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Don\'t close this screen. We\'ll automatically update when payment is confirmed.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: ResponsiveUtils.micro(context),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
