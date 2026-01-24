import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/rewards.dart';
import '../services/rewards_service.dart';
import '../utils/responsive_utils.dart';

class RewardsCenterScreen extends StatefulWidget {
  const RewardsCenterScreen({super.key});

  @override
  State<RewardsCenterScreen> createState() => _RewardsCenterScreenState();
}

class _RewardsCenterScreenState extends State<RewardsCenterScreen>
    with TickerProviderStateMixin {
  RewardSummary? _rewardSummary;
  List<RewardTransaction> _allTransactions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMoreTransactions = true;
  
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadRewardSummary();
    _scrollController.addListener(_onScroll);
  }

  void _initializeControllers() {
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadRewardSummary() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final summary = await RewardsService.getRewardSummary();
      setState(() {
        _rewardSummary = summary;
        _isLoading = false;
      });

      _fadeController.forward();
      await _loadAllTransactions();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllTransactions() async {
    try {
      final transactionList = await RewardsService.getRewardTransactions(
        page: 1,
        pageSize: 20,
      );
      
      setState(() {
        _allTransactions = transactionList.transactions;
        _currentPage = 1;
        _hasMoreTransactions = transactionList.transactions.length >= 20;
      });
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMoreTransactions) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final transactionList = await RewardsService.getRewardTransactions(
        page: _currentPage + 1,
        pageSize: 20,
      );

      setState(() {
        _allTransactions.addAll(transactionList.transactions);
        _currentPage++;
        _hasMoreTransactions = transactionList.transactions.length >= 20;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      print('Error loading more transactions: $e');
    }
  }

  Future<void> _refreshData() async {
    await _loadRewardSummary();
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
                        : _buildContent(),
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
              'Rewards Center',
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.h2(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: _refreshData,
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
                Icons.refresh,
                color: Colors.white,
                size: ResponsiveUtils.iconMedium(context),
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
            'Loading rewards...',
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
              onPressed: _refreshData,
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
                'Try Again',
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

  Widget _buildContent() {
    if (_rewardSummary == null) return Container();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildBalanceOverview(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTransactionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceOverview() {
    final balance = _rewardSummary!.balance;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacingLarge(context),
        vertical: ResponsiveUtils.spacingMedium(context),
      ),
      padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00D4FF),
                          const Color(0xFF9C27B0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4FF).withOpacity(0.3),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: ResponsiveUtils.iconLarge(context),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: ResponsiveUtils.body1(context),
                          ),
                        ),
                        Text(
                          balance.formattedAvailableBalance,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveUtils.h1(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
              Row(
                children: [
                  Expanded(
                    child: _buildBalanceCard(
                      'Earned',
                      balance.formattedLifetimeEarned,
                      Icons.trending_up,
                      const Color(0xFF10B981),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                  Expanded(
                    child: _buildBalanceCard(
                      'Redeemed',
                      balance.formattedLifetimeRedeemed,
                      Icons.redeem,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacingMedium(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: color.withOpacity(0.2),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: ResponsiveUtils.iconMedium(context),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacingSmall(context)),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: ResponsiveUtils.body2(context),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: ResponsiveUtils.h3(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacingLarge(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D4FF),
                  const Color(0xFF9C27B0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.6),
            labelStyle: TextStyle(
              fontSize: ResponsiveUtils.body1(context),
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'History'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSavingsCard(),
          SizedBox(height: ResponsiveUtils.spacingLarge(context)),
          _buildRecentTransactions(),
        ],
      ),
    );
  }

  Widget _buildSavingsCard() {
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10B981),
                          const Color(0xFF059669),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.savings,
                      color: Colors.white,
                      size: ResponsiveUtils.iconMedium(context),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                  Text(
                    'Total Savings',
                    style: TextStyle(
                      color: const Color(0xFF10B981),
                      fontSize: ResponsiveUtils.h3(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.spacingMedium(context)),
              Text(
                _rewardSummary!.formattedTotalSavings,
                style: TextStyle(
                  color: const Color(0xFF10B981),
                  fontSize: ResponsiveUtils.h1(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacingSmall(context)),
              Text(
                'Money saved through reward redemptions',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: ResponsiveUtils.body2(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveUtils.h3(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: ResponsiveUtils.spacingMedium(context)),
        if (_rewardSummary!.recentTransactions.isEmpty)
          _buildEmptyState('No recent transactions')
        else
          ...(_rewardSummary!.recentTransactions.take(5).map(
            (transaction) => _buildTransactionCard(transaction),
          ).toList()),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF00D4FF),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
        itemCount: _allTransactions.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _allTransactions.length) {
            return _buildLoadingIndicator();
          }
          return _buildTransactionCard(_allTransactions[index]);
        },
      ),
    );
  }

  Widget _buildTransactionCard(RewardTransaction transaction) {
    final isCredit = transaction.isCredit;
    final color = isCredit ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final icon = isCredit ? Icons.add_circle : Icons.remove_circle;
    final prefix = isCredit ? '+' : '-';

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingMedium(context)),
      padding: EdgeInsets.all(ResponsiveUtils.spacingMedium(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  RewardsService.getSourceIcon(transaction.source),
                  style: TextStyle(fontSize: ResponsiveUtils.iconMedium(context)),
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacingMedium(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.displayTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveUtils.body1(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      transaction.formattedDate,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: ResponsiveUtils.body2(context),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: color.withOpacity(0.2),
                          border: Border.all(
                            color: color.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: ResponsiveUtils.iconSmall(context),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
                      Text(
                        '$prefix${transaction.formattedAmount}',
                        style: TextStyle(
                          color: color,
                          fontSize: ResponsiveUtils.body1(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacingXSmall(context),
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      transaction.status.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: ResponsiveUtils.caption(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacingMedium(context)),
      child: Center(
        child: CircularProgressIndicator(
          color: const Color(0xFF00D4FF),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacingXLarge(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  color: Colors.white.withOpacity(0.5),
                  size: ResponsiveUtils.iconXLarge(context),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacingMedium(context)),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: ResponsiveUtils.body1(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
