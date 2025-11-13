import 'dart:async';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../app_theme.dart';
import '../services/admin_service.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final StreamController<List<Map<String, dynamic>>> _activityController = StreamController.broadcast();
  final AdminService _adminService = AdminService();
  String _selectedPeriod = 'Day'; // Default to Day

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentActivities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activityController.close();
    super.dispose();
  }

  Future<void> _loadRecentActivities() async {
    try {
      final activities = await _adminService.getCombinedRecentActivities();
      _activityController.add(activities);
    } catch (e) {
      print('Error loading recent activities: $e');
      _activityController.add([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'System Analytics',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          onTap: (index) {
            // Refresh data when switching tabs
            _loadRecentActivities();
          },
          tabs: const [
            Tab(
              text: 'Overview',
              icon: Icon(Icons.dashboard_rounded),
            ),
            Tab(
              text: 'Analytics',
              icon: Icon(Icons.analytics_rounded),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(theme),
          _buildUsersTab(theme),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Key metrics cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  theme,
                  'Total Users',
                  'Loading...',
                  Icons.people_rounded,
                  AppTheme.primaryBlue,
                  _adminService.getTotalUsersStream(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  theme,
                  'Active This Week',
                  'Loading...',
                  Icons.person_rounded,
                  AppTheme.successGreen,
                  _adminService.getActiveUsersStream(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  theme,
                  'Appointments',
                  'Loading...',
                  Icons.calendar_today_rounded,
                  AppTheme.warningOrange,
                  _adminService.getTotalAppointmentsStream(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  theme,
                  'Reviews',
                  'Loading...',
                  Icons.star_rounded,
                  AppTheme.secondaryTeal,
                  _adminService.getTotalReviewsStream(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Growth charts
          _buildGrowthChart(theme),
          const SizedBox(height: 24),

          // Recent activity
          _buildRecentActivity(theme),
        ],
      ),
    );
  }

  Widget _buildUsersTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trends & Analytics',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // User distribution
          _buildUserDistribution(theme),
          const SizedBox(height: 24),

          // Appointment activity chart
          _buildAppointmentActivityChart(theme),
          const SizedBox(height: 24),

          // Top doctors by activity
          _buildTopDoctors(theme),
        ],
      ),
    );
  }


  Widget _buildMetricCard(ThemeData theme, String title, String value, IconData icon, Color color, Stream<int> valueStream) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 12),
          StreamBuilder<int>(
            stream: valueStream,
            builder: (context, snapshot) {
              final displayValue = snapshot.data?.toString() ?? 'Loading...';
              return Text(
                displayValue,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthChart(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Growth Trends',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<Map<String, int>>(
            stream: _adminService.getUserGrowthStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final growthData = snapshot.data ?? {};
              final thisMonth = growthData['thisMonth'] ?? 0;
              final thisWeek = growthData['thisWeek'] ?? 0;
              final today = growthData['today'] ?? 0;

              // Calculate growth percentages (simplified - you can enhance this)
              final totalUsers = thisMonth + thisWeek + today;
              final monthPercent = totalUsers > 0 ? (thisMonth / totalUsers * 100).round() : 0;
              final weekPercent = totalUsers > 0 ? (thisWeek / totalUsers * 100).round() : 0;
              final todayPercent = totalUsers > 0 ? (today / totalUsers * 100).round() : 0;

              return Row(
                children: [
                  Expanded(
                    child: _buildGrowthItem(
                      theme,
                      'This Month',
                      '+$thisMonth (${monthPercent > 0 ? '+$monthPercent%' : '0%'})',
                      AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGrowthItem(
                      theme,
                      'This Week',
                      '+$thisWeek (${weekPercent > 0 ? '+$weekPercent%' : '0%'})',
                      AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGrowthItem(
                      theme,
                      'Today',
                      '+$today (${todayPercent > 0 ? '+$todayPercent%' : '0%'})',
                      AppTheme.primaryBlue,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthItem(ThemeData theme, String period, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            period,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDistribution(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Distribution',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _adminService.getUserDistributionStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final distribution = snapshot.data ?? [];

              return Column(
                children: distribution.map((item) {
                  final percentage = item['percentage'] as double? ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            item['role'] as String? ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              item['role'] == 'doctor' ? AppTheme.primaryBlue : AppTheme.secondaryTeal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${item['count']} (${percentage.toStringAsFixed(1)}%)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentActivityChart(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Appointment Trend',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButton<String>(
                value: _selectedPeriod,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPeriod = newValue!;
                  });
                },
                items: <String>['Day', 'Week','Month', 'Year'].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, double>>>(
            stream: _adminService.getAppointmentActivityStream(_selectedPeriod),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final spots = snapshot.data ?? [];
              if (spots.isEmpty) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'No appointment data available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 200,
                child: SfCartesianChart(
                  primaryXAxis: NumericAxis(
                    interval: 1,
                    minimum: 1,
                    maximum: 6,
                    axisLabelFormatter: (axisLabelRenderArgs) {
                      List<String> labels;
                      if (_selectedPeriod == 'Day') {
                        labels = ['0-3', '4-7', '8-11', '12-15', '16-19', '20-23'];
                      } else if (_selectedPeriod == 'Month') {
                        labels = ['1-5', '6-10', '11-15', '16-20', '21-25', '26-31'];
                      } else if (_selectedPeriod == 'Week') {
                        labels = ['1', '2', '3', '4', '5', '6-7'];
                      } else {
                        labels = ['1-2', '3-4', '5-6', '7-8', '9-10', '11-12'];
                      }
                      int index = axisLabelRenderArgs.value.toInt() - 1;
                      if (index >= 0 && index < labels.length) {
                        return ChartAxisLabel(labels[index], TextStyle());
                      }
                      return ChartAxisLabel('', TextStyle());
                    },
                  ),
                  primaryYAxis: NumericAxis(),
                  series: <LineSeries<Map<String, double>, double>>[
                    LineSeries<Map<String, double>, double>(
                      dataSource: spots,
                      xValueMapper: (data, _) => data['x'],
                      yValueMapper: (data, _) => data['y'],
                      color: AppTheme.primaryBlue,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopDoctors(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most Active Doctors',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _adminService.getTopDoctorsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final doctors = snapshot.data ?? [];

              if (doctors.isEmpty) {
                return Center(
                  child: Text(
                    'No completed appointments data available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                );
              }

              return Column(
                children: doctors.map((doctor) {
                  final name = doctor['name'] as String? ?? 'Unknown Doctor';
                  final count = doctor['count'] as int? ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildTopUserItem(theme, name, '$count appointments', Icons.person_rounded),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopUserItem(ThemeData theme, String name, String activity, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                activity,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }




  Widget _buildRecentActivity(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _activityController.stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Center(
                  child: Text(
                    'No recent activity',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                );
              }

              return Column(
                children: activities.take(5).map((activity) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildActivityItem(
                      theme,
                      activity['description'] as String? ?? 'Unknown activity',
                      activity['time'] as String? ?? 'Unknown time',
                      activity['icon'] as IconData? ?? Icons.info_rounded,
                      activity['color'] as Color? ?? AppTheme.primaryBlue,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ThemeData theme, String activity, String time, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            activity,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          time,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
