import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_theme.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
// import '../services/native_alarm_service.dart'; // Disabled: switching to server-driven FCM notifications

class ReminderTab extends StatefulWidget {
  const ReminderTab({super.key});

  @override
  State<ReminderTab> createState() => _ReminderTabState();
}

class _ReminderTabState extends State<ReminderTab> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<Reminder> _reminders = [];
  bool _isLoading = false;
  String _selectedFilter = 'All';
  // Hydration scheduling UI state
  bool _hydrationEnabled = false;
  TimeOfDay? _hydrationStart;
  TimeOfDay? _hydrationEnd;
  int _hydrationIntervalMinutes = 120; // default 2 hours

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
    
    _loadReminders();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    // Sample data - in real app, load from Firebase
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      // _reminders = [
      //   Reminder(
      //     id: 'drink_water',
      //     title: 'Drink Water',
      //     description: 'Stay hydrated - 8 glasses per day',
      //     type: ReminderType.hydration,
      //     scheduledTime: DateTime.now().add(const Duration(minutes: 30)),
      //     isCompleted: false,
      //     priority: ReminderPriority.medium,
      //     repeatType: RepeatType.hourly,
      //   ),
      // ];
      _isLoading = false;
    });

    _animationController.forward();
  }

  List<Reminder> get _filteredReminders {
    if (_selectedFilter == 'All') return _reminders;
    if (_selectedFilter == 'Active') return _reminders.where((r) => !r.isCompleted).toList();
    if (_selectedFilter == 'Completed') return _reminders.where((r) => r.isCompleted).toList();
    return _reminders.where((r) => r.type.toString().split('.').last == _selectedFilter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    // Header with stats
                    SliverToBoxAdapter(
                      child: _buildHeader(context, isDark),
                    ),
                    
                    // Filter tabs
                    // SliverToBoxAdapter(
                    //   child: _buildFilterTabs(context, isDark),
                    // ),
                    
                    // Reminders list (from Firestore) with header actions
                    SliverToBoxAdapter(
                      child: _buildRemindersSection(context, isDark),
                    ),

                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final uid = _firebaseService.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? const Stream.empty()
          : FirebaseFirestore.instance
              .collection('reminder')
              .where('userId', isEqualTo: uid)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final total = docs.length;
        final active = docs.where((d) => (d.data()['enabled'] as bool?) == true).length;

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
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Health Reminders',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Active',
                      value: active.toString(),
                      subtitle: 'reminders',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Total',
                      value: total.toString(),
                      subtitle: 'reminders',
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showHydrationScheduleDialog() async {
    final theme = Theme.of(context);
    TimeOfDay start = _hydrationStart ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = _hydrationEnd ?? const TimeOfDay(hour: 20, minute: 0);
    int interval = _hydrationIntervalMinutes;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Water Reminder Settings',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: start);
                        if (picked != null) {
                          start = picked;
                          // Force rebuild of the bottom sheet
                          Navigator.pop(context);
                          await _showHydrationScheduleDialog();
                        }
                      },
                      child: Text('Start: ${start.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: end);
                        if (picked != null) {
                          end = picked;
                          Navigator.pop(context);
                          await _showHydrationScheduleDialog();
                        }
                      },
                      child: Text('End: ${end.format(context)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Interval', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: interval,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 minute')),
                  DropdownMenuItem(value: 2, child: Text('2 minutes')),
                  DropdownMenuItem(value: 5, child: Text('5 minutes')),
                  DropdownMenuItem(value: 15, child: Text('15 minutes')),
                  DropdownMenuItem(value: 60, child: Text('1 hour')),
                  DropdownMenuItem(value: 120, child: Text('2 hours')),
                  DropdownMenuItem(value: 240, child: Text('4 hours')),
                  DropdownMenuItem(value: 360, child: Text('6 hours')),
                ],
                onChanged: (v) {
                  interval = v ?? interval;
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _enableHydrationWith(start, end, interval);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Enable'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _enableHydrationWith(TimeOfDay start, TimeOfDay end, int intervalMinutes) async {
    try {
      await NotificationService().scheduleHydrationWindowed(
        startHour: start.hour,
        startMinute: start.minute,
        endHour: end.hour,
        endMinute: end.minute,
        intervalMinutes: intervalMinutes,
      );
      setState(() {
        _hydrationEnabled = true;
        _hydrationStart = start;
        _hydrationEnd = end;
        _hydrationIntervalMinutes = intervalMinutes;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Water reminders enabled'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enable reminders: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _disableHydrationReminders() async {
    try {
      await NotificationService().cancelHydrationReminders();
      setState(() {
        _hydrationEnabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Water reminders disabled'),
            backgroundColor: AppTheme.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disable reminders: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildStatCard(
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

  Widget _buildFilterTabs(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final filters = ['All', 'Active', 'Completed', 'Medication', 'Appointment'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Reminders',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = _selectedFilter == filter;
                
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppTheme.primaryBlue 
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected 
                            ? AppTheme.primaryBlue 
                            : theme.colorScheme.outline.withOpacity(0.3),
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Text(
                      filter,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected 
                            ? Colors.white 
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersSection(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your Reminders',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  onPressed: _showCreateReminderModal,
                  tooltip: 'Add reminder',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firebaseService.getReminders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return Text('Error loading reminders', style: theme.textTheme.bodyMedium);
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_off_rounded,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No reminders yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create one',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: docs.map((doc) => _buildRemoteReminderCard(context, doc.data(), doc.id)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateReminderModal() async {
    final theme = Theme.of(context);
    final nameCtrl = TextEditingController();
    final messageCtrl = TextEditingController(text: "It's time!");
    TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 20, minute: 0);
    int interval = 15; // default 15 minutes

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_alert_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('Create Reminder', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reminder name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reminder message',
                        hintText: "e.g. Take your medicine",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: start);
                              if (picked != null) setSheet(() => start = picked);
                            },
                            child: Text('From: ${start.format(context)}'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: end);
                              if (picked != null) setSheet(() => end = picked);
                            },
                            child: Text('To: ${end.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: interval,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 minute')),
                        DropdownMenuItem(value: 2, child: Text('2 minutes')),
                        DropdownMenuItem(value: 5, child: Text('5 minutes')),
                        DropdownMenuItem(value: 15, child: Text('15 minutes')),
                        DropdownMenuItem(value: 60, child: Text('1 hour')),
                        DropdownMenuItem(value: 120, child: Text('2 hours')),
                        DropdownMenuItem(value: 240, child: Text('4 hours')),
                        DropdownMenuItem(value: 360, child: Text('6 hours')),
                      ],
                      onChanged: (v) => setSheet(() => interval = v ?? interval),
                      decoration: const InputDecoration(labelText: 'Interval', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          // Capture the parent context before closing modal
                          final parentContext = this.context;
                          Navigator.pop(context);
                          // Save to Firestore
                          final ref = await _firebaseService.addReminder(
                            name: name,
                            message: messageCtrl.text.trim().isEmpty ? "It's time!" : messageCtrl.text.trim(),
                            startHour: start.hour,
                            startMinute: start.minute,
                            endHour: end.hour,
                            endMinute: end.minute,
                            intervalMinutes: interval,
                            enabled: true,
                            tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
                          );
                          if (ref != null) {
                            // Native scheduling disabled. Server (Node cron) will send FCM on schedule.
                            if (mounted) {
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(
                                  content: Text('Reminder "$name" created successfully'),
                                  backgroundColor: AppTheme.secondaryTeal,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRemoteReminderCard(BuildContext context, Map<String, dynamic> data, String docId) {
    final theme = Theme.of(context);
    final enabled = (data['enabled'] as bool?) ?? false;
    final name = (data['name'] as String?) ?? 'Reminder';
    final message = (data['message'] as String?) ?? "It's time!";
    final startHour = (data['startHour'] as num?)?.toInt() ?? 8;
    final startMinute = (data['startMinute'] as num?)?.toInt() ?? 0;
    final endHour = (data['endHour'] as num?)?.toInt() ?? 20;
    final endMinute = (data['endMinute'] as num?)?.toInt() ?? 0;
    final intervalMinutes = (data['intervalMinutes'] as num?)?.toInt() ?? 60;

    String fmt(int h, int m) {
      final t = TimeOfDay(hour: h, minute: m);
      return t.format(context);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.access_alarm_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'From ${fmt(startHour, startMinute)} to ${fmt(endHour, endMinute)}  •  Every ${intervalMinutes}m',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Message: $message',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (v) async {
                    await _firebaseService.updateReminderEnabled(reminderId: docId, enabled: v);
                    // Native scheduling disabled. Server (Node cron) reads Firestore and handles sends.
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled
                        ? null
                        : () async {
                            // Edit modal
                            await _showEditReminderModal(
                              docId: docId,
                              initialName: name,
                              initialMessage: message,
                              startHour: startHour,
                              startMinute: startMinute,
                              endHour: endHour,
                              endMinute: endMinute,
                              intervalMinutes: intervalMinutes,
                            );
                          },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: enabled
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                return AlertDialog(
                                  title: const Text('Delete Reminder'),
                                  content: Text('Are you sure you want to delete "$name"? This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('No'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Yes, delete'),
                                    ),
                                  ],
                                );
                              },
                            ) ?? false;
                            if (!confirm) return;
                            // Native cancel disabled. Server relies on Firestore deletes.
                            try {
                              await _firebaseService.deleteReminder(docId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Reminder "$name" deleted'),
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Could not delete: missing permission (check Firestore rules).'),
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditReminderModal({
    required String docId,
    required String initialName,
    required String initialMessage,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int intervalMinutes,
  }) async {
    final theme = Theme.of(context);
    final nameCtrl = TextEditingController(text: initialName);
    final messageCtrl = TextEditingController(text: initialMessage);
    TimeOfDay start = TimeOfDay(hour: startHour, minute: startMinute);
    TimeOfDay end = TimeOfDay(hour: endHour, minute: endMinute);
    int interval = intervalMinutes;
    // Coerce interval to one of allowed values
    final allowed = <int>{1, 2, 5, 15, 60, 120, 240, 360};
    if (!allowed.contains(interval)) interval = 15;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('Edit Reminder', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reminder name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reminder message',
                        hintText: 'e.g. Take your medicine',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: start);
                              if (picked != null) setSheet(() => start = picked);
                            },
                            child: Text('From: ${start.format(context)}'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: end);
                              if (picked != null) setSheet(() => end = picked);
                            },
                            child: Text('To: ${end.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: interval,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 minute')),
                        DropdownMenuItem(value: 2, child: Text('2 minutes')),
                        DropdownMenuItem(value: 5, child: Text('5 minutes')),
                        DropdownMenuItem(value: 15, child: Text('15 minutes')),
                        DropdownMenuItem(value: 60, child: Text('1 hour')),
                        DropdownMenuItem(value: 120, child: Text('2 hours')),
                        DropdownMenuItem(value: 240, child: Text('4 hours')),
                        DropdownMenuItem(value: 360, child: Text('6 hours')),
                      ],
                      onChanged: (v) => setSheet(() => interval = v ?? interval),
                      decoration: const InputDecoration(labelText: 'Interval', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final msg = messageCtrl.text.trim().isEmpty ? "It's time!" : messageCtrl.text.trim();
                          if (name.isEmpty) return;
                          Navigator.pop(context);
                          await _firebaseService.updateReminderFields(
                            reminderId: docId,
                            name: name,
                            message: msg,
                            startHour: start.hour,
                            startMinute: start.minute,
                            endHour: end.hour,
                            endMinute: end.minute,
                            intervalMinutes: interval,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Reminder "$name" updated'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        },
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Future<void> _scheduleHydrationReminders() async {
  //   try {
  //     await NotificationService().scheduleDailyHydrationReminders();
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: const Text('Hydration reminders scheduled successfully'),
  //           backgroundColor: AppTheme.successGreen,
  //           behavior: SnackBarBehavior.floating,
  //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Failed to schedule reminders: $e'),
  //           backgroundColor: AppTheme.errorRed,
  //           behavior: SnackBarBehavior.floating,
  //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //         ),
  //       );
  //     }
  //   }
  // }

  // Widget _buildReminderCard(BuildContext context, Reminder reminder) {
  //   final theme = Theme.of(context);
  //   final color = _getReminderColor(reminder.type);
  //   final timeUntil = reminder.scheduledTime.difference(DateTime.now());
  //
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 16),
  //     decoration: BoxDecoration(
  //       color: theme.colorScheme.surface,
  //       borderRadius: BorderRadius.circular(20),
  //       border: Border.all(
  //         color: color.withOpacity(0.2),
  //         width: 1,
  //       ),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.05),
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       children: [
  //         ListTile(
  //           contentPadding: const EdgeInsets.all(20),
  //           leading: Container(
  //             padding: const EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: color.withOpacity(0.1),
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: Icon(
  //               _getReminderIcon(reminder.type),
  //               color: color,
  //               size: 24,
  //             ),
  //           ),
  //           title: Text(
  //             reminder.title,
  //             style: theme.textTheme.titleMedium?.copyWith(
  //               fontWeight: FontWeight.bold,
  //               decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
  //               color: reminder.isCompleted
  //                   ? theme.colorScheme.onSurface.withOpacity(0.5)
  //                   : null,
  //             ),
  //           ),
  //           subtitle: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const SizedBox(height: 4),
  //               Text(
  //                 reminder.description,
  //                 style: theme.textTheme.bodyMedium?.copyWith(
  //                   color: theme.colorScheme.onSurface.withOpacity(0.6),
  //                 ),
  //               ),
  //               const SizedBox(height: 8),
  //               Row(
  //                 children: [
  //                   Icon(
  //                     Icons.schedule_rounded,
  //                     size: 16,
  //                     color: color,
  //                   ),
  //                   const SizedBox(width: 4),
  //                   Text(
  //                     _formatTime(reminder.scheduledTime),
  //                     style: theme.textTheme.bodySmall?.copyWith(
  //                       color: color,
  //                       fontWeight: FontWeight.w600,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   Container(
  //                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  //                     decoration: BoxDecoration(
  //                       color: _getPriorityColor(reminder.priority).withOpacity(0.1),
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                     child: Text(
  //                       _getPriorityText(reminder.priority),
  //                       style: theme.textTheme.bodySmall?.copyWith(
  //                         color: _getPriorityColor(reminder.priority),
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //           trailing: Checkbox(
  //             value: reminder.isCompleted,
  //             onChanged: (value) {
  //               HapticFeedback.lightImpact();
  //               setState(() {
  //                 reminder.isCompleted = value ?? false;
  //               });
  //               _showCompletionFeedback(reminder);
  //             },
  //             activeColor: color,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(4),
  //             ),
  //           ),
  //         ),
  //         if (!reminder.isCompleted && timeUntil.inMinutes > 0 && timeUntil.inDays < 1)
  //           Container(
  //             width: double.infinity,
  //             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  //             decoration: BoxDecoration(
  //               color: color.withOpacity(0.05),
  //               borderRadius: const BorderRadius.only(
  //                 bottomLeft: Radius.circular(20),
  //                 bottomRight: Radius.circular(20),
  //               ),
  //             ),
  //             child: Text(
  //               timeUntil.inHours > 0
  //                   ? 'Due in ${timeUntil.inHours}h ${timeUntil.inMinutes % 60}m'
  //                   : 'Due in ${timeUntil.inMinutes}m',
  //               style: theme.textTheme.bodySmall?.copyWith(
  //                 color: color,
  //                 fontWeight: FontWeight.w600,
  //               ),
  //               textAlign: TextAlign.center,
  //             ),
  //           ),
  //         if (reminder.type == ReminderType.hydration)
  //           Container(
  //             width: double.infinity,
  //             padding: const EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               color: theme.colorScheme.surface,
  //               borderRadius: const BorderRadius.only(
  //                 bottomLeft: Radius.circular(20),
  //                 bottomRight: Radius.circular(20),
  //               ),
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Row(
  //                   children: [
  //                     Icon(Icons.water_drop_rounded, color: color, size: 18),
  //                     const SizedBox(width: 8),
  //                     Text(
  //                       _hydrationEnabled ? 'Water reminders are ON' : 'Water reminders are OFF',
  //                       style: theme.textTheme.bodyMedium?.copyWith(
  //                         fontWeight: FontWeight.w600,
  //                         color: _hydrationEnabled ? color : theme.colorScheme.onSurface,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 const SizedBox(height: 12),
  //                 if (_hydrationEnabled && _hydrationStart != null && _hydrationEnd != null)
  //                   Text(
  //                     'Window: ${_hydrationStart!.format(context)} - ${_hydrationEnd!.format(context)}, Interval: ${_hydrationIntervalMinutes}m',
  //                     style: theme.textTheme.bodySmall?.copyWith(
  //                       color: theme.colorScheme.onSurface.withOpacity(0.7),
  //                     ),
  //                   ),
  //                 const SizedBox(height: 12),
  //                 Row(
  //                   children: [
  //                     Expanded(
  //                       child: OutlinedButton.icon(
  //                         onPressed: _hydrationEnabled ? _showHydrationScheduleDialog : _showHydrationScheduleDialog,
  //                         icon: const Icon(Icons.settings_rounded, size: 18),
  //                         label: Text(_hydrationEnabled ? 'Edit' : 'Enable'),
  //                         style: OutlinedButton.styleFrom(
  //                           foregroundColor: color,
  //                           side: BorderSide(color: color),
  //                           padding: const EdgeInsets.symmetric(vertical: 12),
  //                         ),
  //                       ),
  //                     ),
  //                     const SizedBox(width: 12),
  //                     Expanded(
  //                       child: OutlinedButton.icon(
  //                         onPressed: _hydrationEnabled ? _disableHydrationReminders : _showHydrationScheduleDialog,
  //                         icon: Icon(_hydrationEnabled ? Icons.stop_circle_rounded : Icons.play_circle_rounded, size: 18),
  //                         label: Text(_hydrationEnabled ? 'Disable' : 'Enable'),
  //                         style: OutlinedButton.styleFrom(
  //                           foregroundColor: _hydrationEnabled ? theme.colorScheme.error : color,
  //                           side: BorderSide(color: _hydrationEnabled ? theme.colorScheme.error : color),
  //                           padding: const EdgeInsets.symmetric(vertical: 12),
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  // Color _getReminderColor(ReminderType type) {
  //   switch (type) {
  //     case ReminderType.medication:
  //       return AppTheme.primaryBlue;
  //     case ReminderType.appointment:
  //       return AppTheme.successGreen;
  //     case ReminderType.exercise:
  //       return AppTheme.warningOrange;
  //     case ReminderType.hydration:
  //       return AppTheme.secondaryTeal;
  //     case ReminderType.healthCheck:
  //       return AppTheme.errorRed;
  //     case ReminderType.wellness:
  //       return AppTheme.neutralGray;
  //   }
  // }
  //
  // IconData _getReminderIcon(ReminderType type) {
  //   switch (type) {
  //     case ReminderType.medication:
  //       return Icons.medication_rounded;
  //     case ReminderType.appointment:
  //       return Icons.calendar_today_rounded;
  //     case ReminderType.exercise:
  //       return Icons.fitness_center_rounded;
  //     case ReminderType.hydration:
  //       return Icons.water_drop_rounded;
  //     case ReminderType.healthCheck:
  //       return Icons.health_and_safety_rounded;
  //     case ReminderType.wellness:
  //       return Icons.spa_rounded;
  //   }
  // }
  //
  // Color _getPriorityColor(ReminderPriority priority) {
  //   switch (priority) {
  //     case ReminderPriority.high:
  //       return AppTheme.errorRed;
  //     case ReminderPriority.medium:
  //       return AppTheme.warningOrange;
  //     case ReminderPriority.low:
  //       return AppTheme.successGreen;
  //   }
  // }
  //
  // String _getPriorityText(ReminderPriority priority) {
  //   switch (priority) {
  //     case ReminderPriority.high:
  //       return 'High';
  //     case ReminderPriority.medium:
  //       return 'Med';
  //     case ReminderPriority.low:
  //       return 'Low';
  //   }
  // }
  //
  // String _formatTime(DateTime dateTime) {
  //   final now = DateTime.now();
  //   final difference = dateTime.difference(now);
  //
  //   if (difference.inDays == 0) {
  //     return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  //   } else if (difference.inDays == 1) {
  //     return 'Tomo ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  //   } else if (difference.inDays < 7) {
  //     final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  //     return '${weekdays[dateTime.weekday - 1]} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  //   } else {
  //     return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  //   }
  // }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year && 
           dateTime.month == now.month && 
           dateTime.day == now.day;
  }

  // void _showCompletionFeedback(Reminder reminder) {
  //   if (reminder.isCompleted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('✅ ${reminder.title} completed!'),
  //         backgroundColor: AppTheme.successGreen,
  //         behavior: SnackBarBehavior.floating,
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //       ),
  //     );
  //   }
  // }

  void _showAddReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.add_rounded,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(width: 12),
            const Text('Add Reminder'),
          ],
        ),
        content: const Text(
          'This feature will allow you to create custom health reminders with notifications and scheduling options.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Add reminder feature coming soon!'),
                  backgroundColor: AppTheme.primaryBlue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class Reminder {
  final String id;
  final String title;
  final String description;
  final ReminderType type;
  final DateTime scheduledTime;
  bool isCompleted;
  final ReminderPriority priority;
  final RepeatType repeatType;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.scheduledTime,
    required this.isCompleted,
    required this.priority,
    required this.repeatType,
  });
}

enum ReminderType {
  medication,
  appointment,
  exercise,
  hydration,
  healthCheck,
  wellness,
}

enum ReminderPriority {
  high,
  medium,
  low,
}

enum RepeatType {
  none,
  daily,
  weekly,
  monthly,
  hourly,
}
