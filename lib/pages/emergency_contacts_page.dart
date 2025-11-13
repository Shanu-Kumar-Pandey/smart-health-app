import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../services/firebase_service.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<EmergencyContact> _emergencyContacts = [];
  List<EmergencyService> _emergencyServices = [];
  bool _isLoading = false;

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
    
    _loadEmergencyContacts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadEmergencyContacts() async {
    setState(() {
      _isLoading = true;
    });
    
    // Sample data - in real app, load from Firebase
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _emergencyContacts = [
        EmergencyContact(
          id: '1',
          name: 'Dr. Sarah Johnson',
          relationship: 'Primary Doctor',
          phone: '+1-555-0123',
          email: 'dr.johnson@healthcenter.com',
          type: ContactType.doctor,
          isAvailable24h: false,
        ),
        EmergencyContact(
          id: '2',
          name: 'John Smith',
          relationship: 'Spouse',
          phone: '+1-555-0456',
          email: 'john.smith@email.com',
          type: ContactType.family,
          isAvailable24h: true,
        ),
        EmergencyContact(
          id: '3',
          name: 'Emergency Room',
          relationship: 'City General Hospital',
          phone: '+1-555-0789',
          email: 'emergency@citygeneral.com',
          type: ContactType.hospital,
          isAvailable24h: true,
        ),
      ];
      
      _emergencyServices = [
        EmergencyService(
          name: 'Emergency Services',
          phone: '911',
          description: 'Police, Fire, Medical Emergency',
          icon: Icons.emergency_rounded,
          color: AppTheme.errorRed,
        ),
        EmergencyService(
          name: 'Poison Control',
          phone: '1-800-222-1222',
          description: '24/7 Poison emergency hotline',
          icon: Icons.warning_rounded,
          color: AppTheme.warningOrange,
        ),
        EmergencyService(
          name: 'Crisis Helpline',
          phone: '988',
          description: 'Mental health crisis support',
          icon: Icons.psychology_rounded,
          color: AppTheme.primaryBlue,
        ),
        EmergencyService(
          name: 'Non-Emergency Medical',
          phone: '811',
          description: 'Health information and advice',
          icon: Icons.medical_services_rounded,
          color: AppTheme.secondaryTeal,
        ),
      ];
      
      _isLoading = false;
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
          'Emergency Contacts',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showAddContactDialog,
            icon: Icon(
              Icons.add_rounded,
              color: AppTheme.primaryBlue,
            ),
            tooltip: 'Add contact',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    // SOS Button
                    SliverToBoxAdapter(
                      child: _buildSOSButton(context, isDark),
                    ),
                    
                    // Emergency Services
                    SliverToBoxAdapter(
                      child: _buildEmergencyServices(context, isDark),
                    ),
                    
                    // Personal Contacts
                    SliverToBoxAdapter(
                      child: _buildPersonalContacts(context, isDark),
                    ),
                    
                    // Medical Information
                    SliverToBoxAdapter(
                      child: _buildMedicalInfo(context, isDark),
                    ),
                    
                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSOSButton(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          _showSOSDialog();
        },
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.errorRed,
                AppTheme.errorRed.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.errorRed.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emergency_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SOS EMERGENCY',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Tap and hold for 3 seconds',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '911',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyServices(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency Services',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._emergencyServices.map((service) => _buildServiceCard(context, service)),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, EmergencyService service) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: service.color.withOpacity(0.2),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: service.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            service.icon,
            color: service.color,
            size: 24,
          ),
        ),
        title: Text(
          service.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              service.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: service.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                service.phone,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: service.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _makeCall(service.phone),
          icon: Icon(
            Icons.phone_rounded,
            color: service.color,
          ),
          style: IconButton.styleFrom(
            backgroundColor: service.color.withOpacity(0.1),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalContacts(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Emergency Contacts',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._emergencyContacts.map((contact) => _buildContactCard(context, contact)),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, EmergencyContact contact) {
    final theme = Theme.of(context);
    final color = _getContactColor(contact.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getContactIcon(contact.type),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.relationship,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (contact.isAvailable24h)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '24/7',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildContactAction(
                  context,
                  icon: Icons.phone_rounded,
                  label: 'Call',
                  color: color,
                  onTap: () => _makeCall(contact.phone),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactAction(
                  context,
                  icon: Icons.message_rounded,
                  label: 'Message',
                  color: color,
                  onTap: () => _sendMessage(contact.phone),
                ),
              ),
              if (contact.email.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContactAction(
                    context,
                    icon: Icons.email_rounded,
                    label: 'Email',
                    color: color,
                    onTap: () => _sendEmail(contact.email),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactAction(
    BuildContext context, {
    required IconData icon,
    required String label,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalInfo(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.warningOrange.withOpacity(0.2),
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
          Row(
            children: [
              Icon(
                Icons.medical_information_rounded,
                color: AppTheme.warningOrange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Medical Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMedicalInfoRow('Blood Type', 'O+'),
          _buildMedicalInfoRow('Allergies', 'Penicillin, Shellfish'),
          _buildMedicalInfoRow('Medical Conditions', 'Diabetes Type 2'),
          _buildMedicalInfoRow('Current Medications', 'Metformin 500mg'),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // TODO: Navigate to edit medical info
            },
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.warningOrange.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Update Medical Information',
              style: TextStyle(
                color: AppTheme.warningOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalInfoRow(String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Color _getContactColor(ContactType type) {
    switch (type) {
      case ContactType.doctor:
        return AppTheme.primaryBlue;
      case ContactType.family:
        return AppTheme.successGreen;
      case ContactType.hospital:
        return AppTheme.errorRed;
      case ContactType.friend:
        return AppTheme.warningOrange;
      case ContactType.other:
        return AppTheme.neutralGray;
    }
  }

  IconData _getContactIcon(ContactType type) {
    switch (type) {
      case ContactType.doctor:
        return Icons.medical_services_rounded;
      case ContactType.family:
        return Icons.family_restroom_rounded;
      case ContactType.hospital:
        return Icons.local_hospital_rounded;
      case ContactType.friend:
        return Icons.person_rounded;
      case ContactType.other:
        return Icons.contact_phone_rounded;
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $phoneNumber...'),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Copy',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: phoneNumber));
          },
        ),
      ),
    );
  }

  Future<void> _sendMessage(String phoneNumber) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening messages for $phoneNumber...'),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Copy',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: phoneNumber));
          },
        ),
      ),
    );
  }

  Future<void> _sendEmail(String email) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening email for $email...'),
        backgroundColor: AppTheme.secondaryTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Copy',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: email));
          },
        ),
      ),
    );
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.emergency_rounded,
              color: AppTheme.errorRed,
            ),
            const SizedBox(width: 12),
            const Text('Emergency SOS'),
          ],
        ),
        content: const Text(
          'This will immediately call emergency services (911). Only use in real emergencies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _makeCall('911');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Call 911'),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
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
            const Text('Add Emergency Contact'),
          ],
        ),
        content: const Text(
          'This feature will allow you to add custom emergency contacts with their information and availability.',
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
                  content: const Text('Add contact feature coming soon!'),
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

class EmergencyContact {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final ContactType type;
  final bool isAvailable24h;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.type,
    required this.isAvailable24h,
  });
}

class EmergencyService {
  final String name;
  final String phone;
  final String description;
  final IconData icon;
  final Color color;

  EmergencyService({
    required this.name,
    required this.phone,
    required this.description,
    required this.icon,
    required this.color,
  });
}

enum ContactType {
  doctor,
  family,
  hospital,
  friend,
  other,
}
