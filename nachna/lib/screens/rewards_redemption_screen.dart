import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/rewards.dart';
import '../models/workshop.dart';
import '../services/rewards_service.dart';
import '../utils/responsive_utils.dart';

class RewardsRedemptionScreen extends StatefulWidget {
  final WorkshopSession workshop;
  final double originalAmount;
  final Map<String, String?> workshopDetails;

  const RewardsRedemptionScreen({
    Key? key,
    required this.workshop,
    required this.originalAmount,
    required this.workshopDetails,
  }) : super(key: key);

  @override
  State<RewardsRedemptionScreen> createState() => _RewardsRedemptionScreenState();
}

class _RewardsRedemptionScreenState extends State<RewardsRedemptionScreen>
    with TickerProviderStateMixin {
  RedemptionCalculation? _redemptionCalculation;
  bool _isLoading = true;
  String? _errorMessage;
  double _selectedRedemption = 0.0;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRedemptionCalculation();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadRedemptionCalculation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final calculation = await RewardsService.calculateRedemption(
        workshopUuid: widget.workshop.uuid ?? '',
        workshopAmount: widget.originalAmount,
      );

      setState(() {
        _redemptionCalculation = calculation;
        _selectedRedemption = calculation.workshopInfo.recommendedRedemption;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _proceedWithRedemption() async {
    if (_redemptionCalculation == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
      );

      final redemption = await RewardsService.redeemRewards(
        workshopUuid: widget.workshop.uuid ?? '',
        pointsToRedeem: _selectedRedemption,
        orderAmount: widget.originalAmount,
      );

      Navigator.of(context).pop(); // Close loading dialog

      // Return redemption data to proceed with payment
      Navigator.of(context).pop({
        'redemption': redemption,
        'points_redeemed': _selectedRedemption,
        'discount_amount': redemption.discountAmount,
        'final_amount': redemption.finalAmount,
      });
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar(e.toString());
    }
  }

  void _proceedWithoutRedemption() {
    Navigator.of(context).pop({
      'redemption': null,
      'points_redeemed': 0.0,
      'discount_amount': 0.0,
      'final_amount': widget.originalAmount,
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0A0F),
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
              const Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _buildRedemptionContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacingLarge(context),
        vertical: ResponsiveUtils.spacingMedium(context),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: ResponsiveUtils.iconMedium(context),
              ),
            ),
          ),
          SizedBox(width: ResponsiveUtils.spacingMedium(context)),
          Expanded(
            child: Text(
              'Use Rewards',
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.h2(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFF00D4FF),
            strokeWidth: 3,
          ),
          SizedBox(height: ResponsiveUtils.spacingLarge(context)),
          Text(
            'Loading reward options...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: ResponsiveUtils.body1(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
        padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.red.withOpacity(0.1),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: ResponsiveUtils.iconXLarge(context),
            ),
            SizedBox(height: ResponsiveUtils.spacingMedium(context)),
            Text(
              'Error Loading Rewards',
              style: TextStyle(
                color: Colors.red,
                fontSize: ResponsiveUtils.h3(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacingSmall(context)),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: ResponsiveUtils.body2(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.spacingLarge(context)),
            ElevatedButton(
              onPressed: _proceedWithoutRedemption,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.spacingMedium(context),
                  horizontal: ResponsiveUtils.spacingXLarge(context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Continue Without Rewards',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveUtils.body1(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedemptionContent() {
    if (_redemptionCalculation == null) return Container();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWorkshopSummary(),
              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
              _buildRewardBalance(),
              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
              if (_redemptionCalculation!.canRedeem) ...[
                _buildRedemptionSlider(),
                SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                _buildPaymentSummary(),
                SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                _buildActionButtons(),
              ] else ...[
                _buildNoRedemptionAvailable(),
                SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                _buildContinueButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkshopSummary() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workshop Details',
            style: TextStyle(
              color: const Color(0xFF00D4FF),
              fontSize: ResponsiveUtils.h3(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveUtils.spacingMedium(context)),
          _buildDetailRow('Song', widget.workshop.song ?? 'TBA'),
          _buildDetailRow('Artist', widget.workshop.artist ?? 'TBA'),
          _buildDetailRow('Date', widget.workshop.date ?? 'TBA'),
          _buildDetailRow('Time', widget.workshop.time ?? 'TBA'),
          SizedBox(height: ResponsiveUtils.spacingMedium(context)),
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.spacingMedium(context)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF00D4FF).withOpacity(0.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Workshop Amount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveUtils.body1(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '₹${widget.originalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: const Color(0xFF00D4FF),
                    fontSize: ResponsiveUtils.h3(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.spacingSmall(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveUtils.screenWidth(context) * 0.25,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: ResponsiveUtils.body2(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.body2(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardBalance() {
    final workshopInfo = _redemptionCalculation!.workshopInfo;
    
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.2),
            const Color(0xFF059669).withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wallet,
                color: const Color(0xFF10B981),
                size: ResponsiveUtils.iconMedium(context),
              ),
              SizedBox(width: ResponsiveUtils.spacingSmall(context)),
              Text(
                'Your Reward Balance',
                style: TextStyle(
                  color: const Color(0xFF10B981),
                  fontSize: ResponsiveUtils.h3(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacingMedium(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: ResponsiveUtils.body1(context),
                ),
              ),
              Text(
                workshopInfo.formattedAvailableBalance,
                style: TextStyle(
                  color: const Color(0xFF10B981),
                  fontSize: ResponsiveUtils.h3(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacingSmall(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Max Redeemable',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: ResponsiveUtils.body2(context),
                ),
              ),
              Text(
                '₹${workshopInfo.maxRedeemablePoints.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveUtils.body1(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionSlider() {
    final workshopInfo = _redemptionCalculation!.workshopInfo;
    final maxRedeemable = workshopInfo.maxRedeemablePoints;
    
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Reward Points to Use',
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveUtils.h3(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveUtils.spacingLarge(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: ResponsiveUtils.body2(context),
                ),
              ),
              Text(
                '₹${_selectedRedemption.toStringAsFixed(0)}',
                style: TextStyle(
                  color: const Color(0xFF00D4FF),
                  fontSize: ResponsiveUtils.h2(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${maxRedeemable.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: ResponsiveUtils.body2(context),
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacingMedium(context)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00D4FF),
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: const Color(0xFF00D4FF),
              overlayColor: const Color(0xFF00D4FF).withOpacity(0.3),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: _selectedRedemption,
              min: 0,
              max: maxRedeemable,
              divisions: maxRedeemable > 0 ? (maxRedeemable / 10).round() : 1,
              onChanged: (value) {
                setState(() {
                  _selectedRedemption = value;
                });
              },
            ),
          ),
          SizedBox(height: ResponsiveUtils.spacingMedium(context)),
          Row(
            children: [
              Expanded(
                child: _buildQuickSelectButton('25%', maxRedeemable * 0.25),
              ),
              SizedBox(width: ResponsiveUtils.spacingSmall(context)),
              Expanded(
                child: _buildQuickSelectButton('50%', maxRedeemable * 0.5),
              ),
              SizedBox(width: ResponsiveUtils.spacingSmall(context)),
              Expanded(
                child: _buildQuickSelectButton('Max', maxRedeemable),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSelectButton(String label, double value) {
    final isSelected = (_selectedRedemption - value).abs() < 1;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRedemption = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: ResponsiveUtils.spacingSmall(context),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? const Color(0xFF00D4FF).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF00D4FF)
                : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00D4FF) : Colors.white,
            fontSize: ResponsiveUtils.body2(context),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final calculation = RewardsService.calculateFinalAmount(
      originalAmount: widget.originalAmount,
      pointsToRedeem: _selectedRedemption,
      exchangeRate: _redemptionCalculation!.exchangeRate,
    );

    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.2),
            const Color(0xFF7C3AED).withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: const Color(0xFF8B5CF6),
                size: ResponsiveUtils.iconMedium(context),
              ),
              SizedBox(width: ResponsiveUtils.spacingSmall(context)),
              Text(
                'Payment Summary',
                style: TextStyle(
                  color: const Color(0xFF8B5CF6),
                  fontSize: ResponsiveUtils.h3(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacingLarge(context)),
          _buildSummaryRow('Workshop Amount', '₹${widget.originalAmount.toStringAsFixed(0)}'),
          if (_selectedRedemption > 0) ...[
            _buildSummaryRow(
              'Reward Discount',
              '- ${calculation["formatted_discount"]}',
              color: const Color(0xFF10B981),
            ),
            Divider(color: Colors.white.withOpacity(0.3)),
          ],
          _buildSummaryRow(
            'Final Amount',
            calculation["formatted_final_amount"],
            isTotal: true,
          ),
          if (_selectedRedemption > 0)
            _buildSummaryRow(
              'You Save',
              calculation["formatted_savings"],
              color: const Color(0xFF10B981),
              isSubtext: true,
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? color,
    bool isTotal = false,
    bool isSubtext = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingSmall(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color ?? (isTotal ? Colors.white : Colors.white.withOpacity(0.7)),
              fontSize: isSubtext 
                  ? ResponsiveUtils.body2(context)
                  : isTotal 
                      ? ResponsiveUtils.h3(context)
                      : ResponsiveUtils.body1(context),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? (isTotal ? const Color(0xFF8B5CF6) : Colors.white),
              fontSize: isSubtext 
                  ? ResponsiveUtils.body2(context)
                  : isTotal 
                      ? ResponsiveUtils.h2(context)
                      : ResponsiveUtils.body1(context),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _proceedWithRedemption,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingLarge(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payment,
                  color: Colors.white,
                  size: ResponsiveUtils.iconMedium(context),
                ),
                SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                Text(
                  'Proceed to Payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveUtils.h3(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.spacingMedium(context)),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _proceedWithoutRedemption,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingMedium(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Text(
              'Skip Rewards',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: ResponsiveUtils.body1(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoRedemptionAvailable() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.orange.withOpacity(0.1),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange,
            size: ResponsiveUtils.iconXLarge(context),
          ),
          SizedBox(height: ResponsiveUtils.spacingMedium(context)),
          Text(
            'Rewards Not Available',
            style: TextStyle(
              color: Colors.orange,
              fontSize: ResponsiveUtils.h3(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveUtils.spacingSmall(context)),
          Text(
            _redemptionCalculation?.message ?? 'No reward points available for this workshop',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: ResponsiveUtils.body1(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _proceedWithoutRedemption,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D4FF),
          padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingLarge(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Continue to Payment',
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveUtils.h3(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
