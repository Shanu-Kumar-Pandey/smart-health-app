import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_theme.dart';
import '../services/firebase_service.dart';
import '../services/health_metrics_service.dart';

class HealthTrackingPage extends StatefulWidget {
  const HealthTrackingPage({super.key});

  @override
  State<HealthTrackingPage> createState() => _HealthTrackingPageState();
}

class _HealthTrackingPageState extends State<HealthTrackingPage> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final HealthMetricsService _healthMetricsService = HealthMetricsService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<HealthMetric> _healthMetrics = [];
  List<HealthRecord> _recentRecords = [];
  bool _isLoading = false;
  String _selectedPeriod = 'Week';

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
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadHealthData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    super.dispose();
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch recent records from service
      final recentRecords = await _healthMetricsService.getRecentHealthRecords(limit: 5);

      setState(() {
        _recentRecords = recentRecords;
        _isLoading = false;
      });

    } catch (e) {
      // If service call fails, fall back to empty list or show error
      setState(() {
        _recentRecords = [];
        _isLoading = false;
      });

      // Optionally show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading recent records: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Sample data for health metrics - keeping this as is for now since user only asked for recent records
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _healthMetrics = [
        HealthMetric(
          id: '1',
          name: 'Blood Pressure',
          unit: 'mmHg',
          currentValue: '120/80',
          normalRange: '90-120/60-80',
          icon: Icons.favorite_rounded,
          color: AppTheme.errorRed,
          status: HealthStatus.normal,
          lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
          trend: HealthTrend.stable,
        ),
        HealthMetric(
          id: '2',
          name: 'Blood Sugar',
          unit: 'mg/dL',
          currentValue: '95',
          normalRange: '70-100',
          icon: Icons.water_drop_rounded,
          color: AppTheme.primaryBlue,
          status: HealthStatus.normal,
          lastUpdated: DateTime.now().subtract(const Duration(hours: 4)),
          trend: HealthTrend.improving,
        ),
        HealthMetric(
          id: '3',
          name: 'Weight',
          unit: 'kg',
          currentValue: '72.5',
          normalRange: '65-75',
          icon: Icons.monitor_weight_rounded,
          color: AppTheme.successGreen,
          status: HealthStatus.normal,
          lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
          trend: HealthTrend.declining,
        ),
        HealthMetric(
          id: '4',
          name: 'Heart Rate',
          unit: 'bpm',
          currentValue: '72',
          normalRange: '60-100',
          icon: Icons.monitor_heart_rounded,
          color: AppTheme.warningOrange,
          status: HealthStatus.normal,
          lastUpdated: DateTime.now().subtract(const Duration(minutes: 30)),
          trend: HealthTrend.stable,
        ),
        HealthMetric(
          id: '5',
          name: 'Body Temprature',
          unit: '°C',
          currentValue: '36.8',
          normalRange: '36.1-37.2',
          icon: Icons.thermostat_rounded,
          color: AppTheme.secondaryTeal,
          status: HealthStatus.normal,
          lastUpdated: DateTime.now().subtract(const Duration(hours: 8)),
          trend: HealthTrend.stable,
        ),
        HealthMetric(
          id: '6',
          name: 'Oxygen Saturation',
          unit: '%',
          currentValue: '98',
          normalRange: '95-100',
          icon: Icons.air_rounded,
          color: AppTheme.primaryBlue,
          status: HealthStatus.normal,
          lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
          trend: HealthTrend.stable,
        ),
      ];
    });

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'Health Tracking',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        // actions: [
        //   PopupMenuButton<String>(
        //     icon: Icon(
        //       Icons.more_vert_rounded,
        //       color: theme.colorScheme.onSurface,
        //     ),
        //     onSelected: (value) {
        //       setState(() {
        //         _selectedPeriod = value;
        //       });
        //     },
        //     itemBuilder: (context) => [
        //       const PopupMenuItem(value: 'Day', child: Text('Today')),
        //       const PopupMenuItem(value: 'Week', child: Text('This Week')),
        //       const PopupMenuItem(value: 'Month', child: Text('This Month')),
        //       const PopupMenuItem(value: 'Year', child: Text('This Year')),
        //     ],
        //   ),
        // ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    // Health Overview
                    SliverToBoxAdapter(
                      child: _buildHealthOverview(context, isDark),
                    ),
                    
                    // Health Metrics Grid
                    SliverToBoxAdapter(
                      child: _buildHealthMetrics(context, isDark),
                    ),
                    
                    // Recent Records
                    SliverToBoxAdapter(
                      child: _buildRecentRecords(context, isDark),
                    ),
                    
                    // Quick Actions
                    // SliverToBoxAdapter(
                    //   child: _buildQuickActions(context, isDark),
                    // ),

                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 30),
                    ),
                  ],
                ),
              ),
            ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _showAddRecordDialog,
      //   backgroundColor: AppTheme.primaryBlue,
      //   child: const Icon(
      //     Icons.add_rounded,
      //     color: Colors.white,
      //   ),
      // ),
    );
  }

  Widget _buildHealthOverview(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final totalCount = _healthMetrics.length;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A1F2E),
                  const Color(0xFF2D3748),
                ]
              : [
                  AppTheme.primaryBlue,
                  AppTheme.secondaryTeal,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppTheme.primaryBlue).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Health Overview',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<int>(
                  future: _healthMetricsService.countNormalStatusMetrics(),
                  builder: (context, snapshot) {
                    final normalCount = snapshot.data ?? 0;
                    return _buildOverviewCard(
                      context,
                      title: 'Normal',
                      value: normalCount.toString(),
                      subtitle: 'metrics',
                      icon: Icons.check_circle_rounded,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewCard(
                  context,
                  title: 'Total',
                  value: totalCount.toString(),
                  subtitle: 'tracked',
                  icon: Icons.monitor_heart_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white.withOpacity(0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetrics(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health Metrics',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.79,
            ),
            itemCount: _healthMetrics.length,
            itemBuilder: (context, index) {
              return _buildMetricCard(context, _healthMetrics[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, HealthMetric metric) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showMetricDetails(metric);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: metric.color.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Trend
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: metric.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    metric.icon,
                    color: metric.color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                FutureBuilder(
                  future: _getLatestMetricRecord(metric.name),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data == null) {
                      return Icon(
                        _getTrendIcon(metric.trend),
                        color: _getTrendColor(metric.trend),
                        size: 16,
                      );
                    }

                    final latestRecord = snapshot.data!;
                    final currentValue = latestRecord['value'].toString();
                    final calculatedTrend = _healthMetricsService.calculateTrendFromStatus(currentValue, metric.normalRange, metric.name);

                    return Icon(
                      _getTrendIcon(calculatedTrend),
                      color: _getTrendColor(calculatedTrend),
                      size: 16,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metric Name
            Text(
              metric.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),

            // Current Value + Unit (same row)
            // Row(
            //   crossAxisAlignment: CrossAxisAlignment.end,
            //   children: [
            //     Text(
            //       metric.currentValue,
            //       style: theme.textTheme.titleLarge?.copyWith(
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: _getLatestMetricRecord(metric.name),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(
                          'Loading...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        );
                      }

                      if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                        return Text(
                          'No data available',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        );
                      }

                      final latestRecord = snapshot.data!;
                      return Text(
                        '${latestRecord['value']} ${metric.unit}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: metric.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status + Last Updated (same row)
            Row(
              children: [
                // Status left
                FutureBuilder<Map<String, dynamic>?>(
                  future: _getLatestMetricRecord(metric.name),
                  builder: (context, snapshot) {
                    HealthStatus calculatedStatus = metric.status;

                    if (snapshot.hasData && snapshot.data != null) {
                      final latestRecord = snapshot.data!;
                      calculatedStatus = _healthMetricsService.calculateHealthStatus(
                        latestRecord['value'].toString(),
                        metric.normalRange,
                        metric.name
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(calculatedStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(calculatedStatus),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getStatusColor(calculatedStatus),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                // Last Updated right
                FutureBuilder<Map<String, dynamic>?>(
                  future: _getLatestMetricRecord(metric.name),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data == null) {
                      return Text(
                        'Never',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      );
                    }

                    final latestRecord = snapshot.data!;
                    return Text(
                      _healthMetricsService.getTimeAgo(latestRecord['date'].toDate()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRecords(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Records',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // TextButton(
              //   onPressed: () {
              //     // TODO: Navigate to all records
              //   },
              //   child: Text(
              //     'View All',
              //     style: TextStyle(
              //       color: AppTheme.primaryBlue,
              //       fontWeight: FontWeight.w600,
              //     ),
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 16),
          ..._recentRecords.map((record) => _buildRecordCard(context, record)),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, HealthRecord record) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.metricName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (record.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.notes,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _healthMetricsService.getTimeAgo(record.timestamp),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildQuickActions(BuildContext context, bool isDark) {
  //   final theme = Theme.of(context);
  //
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 20),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Quick Actions',
  //           style: theme.textTheme.titleLarge?.copyWith(
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         Row(
  //           children: [
  //             Expanded(
  //               child: _buildActionButton(
  //                 context,
  //                 icon: Icons.add_chart_rounded,
  //                 title: 'Add Record',
  //                 color: AppTheme.primaryBlue,
  //                 onTap: _showAddRecordDialog,
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: _buildActionButton(
  //                 context,
  //                 icon: Icons.analytics_rounded,
  //                 title: 'View Trends',
  //                 color: AppTheme.secondaryTeal,
  //                 onTap: () {
  //                   // TODO: Navigate to trends page
  //                 },
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.normal:
        return AppTheme.successGreen;
      case HealthStatus.warning:
        return AppTheme.warningOrange;
      case HealthStatus.critical:
        return AppTheme.errorRed;
    }
  }

  String _getStatusText(HealthStatus status) {
    switch (status) {
      case HealthStatus.normal:
        return 'Normal';
      case HealthStatus.warning:
        return 'Warning';
      case HealthStatus.critical:
        return 'Critical';
    }
  }

  // Helper method to get trend icon based on trend
  IconData _getTrendIcon(HealthTrend trend) {
    switch (trend) {
      case HealthTrend.improving:
        return Icons.trending_up_rounded;
      case HealthTrend.declining:
        return Icons.trending_down_rounded;
      case HealthTrend.stable:
        return Icons.trending_flat_rounded;
    }
  }

  // Helper method to get trend color based on trend
  Color _getTrendColor(HealthTrend trend) {
    switch (trend) {
      case HealthTrend.improving:
        return AppTheme.warningOrange; // Orange for above range
      case HealthTrend.declining:
        return AppTheme.errorRed; // Red for below range
      case HealthTrend.stable:
        return AppTheme.neutralGray; // Gray for within range
    }
  }

  // Helper method to get latest metric record using service
  Future<Map<String, dynamic>?> _getLatestMetricRecord(String metricName) async {
    try {
      return await _healthMetricsService.getLatestMetricRecord(metricName);
    } catch (e) {
      return null;
    }
  }

  Future<void> _showMetricDetails(HealthMetric metric) async {
    String currentValue = 'Loading...';
    String lastUpdated = 'Loading...';
    HealthStatus currentStatus = HealthStatus.normal;

    try {
      final latestRecord = await _healthMetricsService.getLatestMetricRecord(metric.name);

      if (latestRecord != null) {
        currentValue = latestRecord['value'].toString();
        final timestamp = (latestRecord['date'] as Timestamp).toDate();
        lastUpdated = _healthMetricsService.getTimeAgo(timestamp);
        currentStatus = _healthMetricsService.calculateHealthStatus(currentValue, metric.normalRange, metric.name);
      } else {
        currentValue = 'No data available';
        lastUpdated = 'Never';
        currentStatus = HealthStatus.normal;
      }
    } catch (e) {
      currentValue = 'Error loading data';
      lastUpdated = 'Error';
      currentStatus = HealthStatus.normal;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              metric.icon,
              color: metric.color,
            ),
            const SizedBox(width: 10),
            Text(metric.name),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current: $currentValue ${metric.unit}'),
            const SizedBox(height: 8),
            Text('Normal Range: ${metric.normalRange} ${metric.unit}'),
            const SizedBox(height: 8),
            Text('Status: ${_getStatusText(currentStatus)}'),
            const SizedBox(height: 8),
            Text('Last Updated: $lastUpdated'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showAddRecordDialog(metric: metric);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: metric.color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Record'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddRecordDialog({required HealthMetric metric}) async {
    final _formKey = GlobalKey<FormState>();
    String value = '';
    String notes = '';
    final isBloodPressure = metric.name.toLowerCase().contains('pressure');

    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(metric.icon, color: metric.color),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Add ${metric.name} Record',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isBloodPressure) ..._buildBloodPressureFields()
                else
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: '${metric.name} (${metric.unit})',
                      hintText: 'Enter your ${metric.name.toLowerCase()}',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onSaved: (val) => value = val!,
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Add any additional notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onSaved: (val) => notes = val ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();

                  final currentContext = context;

                // Show loading indicator
                showDialog(
                  context: currentContext,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    return WillPopScope(
                      onWillPop: () async => false,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                );

                try {
                  // Update existing record or create new one using service
                  await _healthMetricsService.saveHealthRecord(
                    metricName: metric.name,
                    value: isBloodPressure ? 
                        '${_systolicController.text}/${_diastolicController.text}' : 
                        value,
                    unit: metric.unit,
                    notes: notes.isNotEmpty ? notes : null,
                  );

                // Close dialogs and form
                if (mounted) {
                  Navigator.of(currentContext, rootNavigator: true).pop(); // Close loading
                  Navigator.of(currentContext, rootNavigator: true).pop(); // Close form
                  _showSuccess('${metric.name} record saved successfully!');
                  _loadHealthData();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(currentContext, rootNavigator: true).pop(); // Close loading
                  _showError('Error saving record: ${e.toString()}');
                }
              }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: metric.color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();

  List<Widget> _buildBloodPressureFields() {
    return [
      TextFormField(
        controller: _systolicController,
        decoration: const InputDecoration(
          labelText: 'Systolic (mmHg)',
          hintText: 'Enter systolic value',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter systolic value';
          }
          if (int.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _diastolicController,
        decoration: const InputDecoration(
          labelText: 'Diastolic (mmHg)',
          hintText: 'Enter diastolic value',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter diastolic value';
          }
          if (int.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    ];
  }


  // Helper method to show error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to show success message
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class HealthMetric {
  final String id;
  final String name;
  final String unit;
  final String currentValue;
  final String normalRange;
  final IconData icon;
  final Color color;
  final HealthStatus status;
  final DateTime lastUpdated;
  final HealthTrend trend;

  HealthMetric({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentValue,
    required this.normalRange,
    required this.icon,
    required this.color,
    required this.status,
    required this.lastUpdated,
    required this.trend,
  });
}
