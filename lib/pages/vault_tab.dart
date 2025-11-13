import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'edit_profile_page.dart';

class VaultTab extends StatefulWidget {
  const VaultTab({super.key});

  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab> {
  final FirebaseService _firebaseService = FirebaseService();
  UserProfile? _userProfile;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  void _showSnack(String message, {bool error = false}) {
    final cs = Theme.of(context).colorScheme;
    final bg = error ? cs.error : cs.primaryContainer;
    final fg = error ? cs.onError : cs.onPrimaryContainer;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bg,
        content: Text(message, style: TextStyle(color: fg)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openAddRecordDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Health Record'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a title'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description'),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.cloud_upload_outlined),
                        title: const Text('Upload file'),
                        subtitle: const Text('Coming soon...'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Uploading option is off'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final uid = _firebaseService.currentUser?.uid;
                          if (uid == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please sign in to add records')),
                            );
                            return;
                          }
                          setState(() => saving = true);
                          try {
                            await FirebaseFirestore.instance.collection('healthrecord').add({
                              'userId': uid,
                              'title': titleCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) Navigator.of(context).pop(true);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to save: $e')),
                            );
                            setState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      if (mounted) {
        _showSnack('Record added');
        await Future.delayed(const Duration(milliseconds: 50));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  Widget _buildHealthRecordsSection() {
    final uid = _firebaseService.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('healthrecord')
              .where('userId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.folder_open, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No health records yet. Tap + to add one.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final docs = snapshot.data!.docs;
            return Column(
              children: [
                for (final d in docs)
                  (() {
                    final data = d.data();
                    final title = (data['title'] ?? '') as String;
                    final description = (data['description'] ?? '') as String;
                    final fileUrl = data['fileUrl'] as String?;
                    return _buildRecordInfoCard(
                      d.id,
                      title.isEmpty ? 'Untitled' : title,
                      description,
                      fileUrl,
                    );
                  })(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordInfoCard(String docId, String title, String description, String? fileUrl) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.description, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _openEditRecordDialog(docId, title, description),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDeleteRecord(docId),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description.isEmpty ? 'No description' : description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (fileUrl != null && fileUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fileUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
             
            ],
          ],
        ),
      ),
    );
  }

  // Map card title to Firestore field and current list from profile
  (String, List<String>)? _mapTitleToFieldAndCurrent(String title) {
    final p = _userProfile;
    if (p == null) return null;
    switch (title) {
      case 'Allergies':
        return ('allergies', (p.allergies ?? const []));
      case 'Current Medications':
        return ('medications', (p.medications ?? const []));
      case 'Vital Signs':
        return ('vitalSigns', (p.vitalSigns ?? const []));
      case 'Lab Reports':
        return ('labReports', (p.labReports ?? const []));
      case 'Chronic Conditions':
        return ('chronicConditions', (p.chronicConditions ?? const []));
      case 'Vaccinations':
        return ('vaccinations', (p.vaccinations ?? const []));
      case 'Surgeries & Procedures':
        return ('surgeries', (p.surgeries ?? const []));
      case 'Lifestyle Goals':
        return ('lifestyleGoals', (p.lifestyleGoals ?? const []));
      default:
        return null;
    }
  }

  Future<void> _openEditListDialog({
    required String fieldKey,
    required String dialogTitle,
    required List<String> current,
  }) async {
    final controller = TextEditingController(text: current.join(', '));
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(dialogTitle),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Comma-separated values',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          final uid = _firebaseService.currentUser?.uid;
                          if (uid == null) {
                            _showSnack('Please sign in', error: true);
                            setState(() => saving = false);
                            return;
                          }
                          final list = controller.text
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          try {
                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              fieldKey: list,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) Navigator.of(context).pop(true);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update: $e')),
                            );
                            setState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      await _loadUserProfile();
      _showSnack('Updated successfully');
    }
  }

  Future<void> _openEditRecordDialog(String id, String currentTitle, String currentDescription) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: currentTitle);
    final descCtrl = TextEditingController(text: currentDescription);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Health Record'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a title'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description'),
                        minLines: 2,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => saving = true);
                          try {
                            await FirebaseFirestore.instance.collection('healthrecord').doc(id).update({
                              'title': titleCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) Navigator.of(context).pop();
                            if (mounted) {
                              _showSnack('Record updated');
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update: $e')),
                            );
                            setState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteRecord(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Record'),
          content: const Text('Are you sure you want to delete this record?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        );
      },
    );
    if (confirmed == true) {
      // Show a small blocking loader while deleting
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: SizedBox(
              height: 48,
              width: 48,
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }
      try {
        await FirebaseFirestore.instance.collection('healthrecord').doc(id).delete();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      } finally {
        if (context.mounted) Navigator.of(context).pop(); // close loader
        if (mounted) {
          _showSnack('Record deleted', error: true);
        }
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _firebaseService.getCurrentUserProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddRecordDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? _buildEmptyState()
              : _buildUserHealthData(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_information_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Health Data Available',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your health information will appear here once you add it',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to add health data page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add health data (coming soon)')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Health Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHealthData() {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final bottomExtra = bottomSafe + kBottomNavigationBarHeight + 24;
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomExtra),
      children: [
        const SizedBox(height: 4),
        if (_userProfile?.name != null) _buildInfoCard(
          'Personal Details',
          Icons.person,
          Colors.blue.shade100,
          [
            'Name: ${_userProfile!.name}',
            if (_userProfile!.age != null) 'Age: ${_userProfile!.age} years',
            if (_userProfile!.gender != null) 'Gender: ${_userProfile!.gender}',
            if (_userProfile!.bloodGroup != null) 'Blood Group: ${_userProfile!.bloodGroup}',
          ],
        ),
        if (_userProfile?.allergies != null && _userProfile!.allergies!.isNotEmpty)
          _buildInfoCard(
            'Allergies',
            Icons.warning,
            Colors.orange.shade100,
            _userProfile!.allergies!.map((allergy) => '• $allergy').toList(),
          ),
        if (_userProfile?.medications != null && _userProfile!.medications!.isNotEmpty)
          _buildInfoCard(
            'Current Medications',
            Icons.medication,
            Colors.green.shade100,
            _userProfile!.medications!.map((med) => '• $med').toList(),
          ),
        if (_userProfile?.vitalSigns != null && _userProfile!.vitalSigns!.isNotEmpty)
          _buildInfoCard(
            'Vital Signs',
            Icons.favorite,
            Colors.red.shade100,
            _userProfile!.vitalSigns!.map((vital) => '• $vital').toList(),
          ),
        if (_userProfile?.labReports != null && _userProfile!.labReports!.isNotEmpty)
          _buildInfoCard(
            'Lab Reports',
            Icons.description,
            Colors.purple.shade100,
            _userProfile!.labReports!.map((report) => '• $report').toList(),
          ),
        if (_userProfile?.chronicConditions != null && _userProfile!.chronicConditions!.isNotEmpty)
          _buildInfoCard(
            'Chronic Conditions',
            Icons.medical_services,
            Colors.indigo.shade100,
            _userProfile!.chronicConditions!.map((condition) => '• $condition').toList(),
          ),
        if (_userProfile?.vaccinations != null && _userProfile!.vaccinations!.isNotEmpty)
          _buildInfoCard(
            'Vaccinations',
            Icons.vaccines,
            Colors.teal.shade100,
            _userProfile!.vaccinations!.map((vaccine) => '• $vaccine').toList(),
          ),
        if (_userProfile?.surgeries != null && _userProfile!.surgeries!.isNotEmpty)
          _buildInfoCard(
            'Surgeries & Procedures',
            Icons.local_hospital,
            Colors.deepOrange.shade100,
            _userProfile!.surgeries!.map((surgery) => '• $surgery').toList(),
          ),
        // Insurance section removed per requirement
        // Emergency contacts removed per requirement
        if (_userProfile?.lifestyleGoals != null && _userProfile!.lifestyleGoals!.isNotEmpty)
          _buildInfoCard(
            'Lifestyle Goals',
            Icons.track_changes,
            Colors.lime.shade100,
            _userProfile!.lifestyleGoals!.map((goal) => '• $goal').toList(),
          ),
        const SizedBox(height: 20),
        // Card(
        //   child: Padding(
        //     padding: const EdgeInsets.all(16),
        //     child: Column(
        //       children: [
        //         Text(
        //           'Add More Health Information',
        //           style: Theme.of(context).textTheme.titleMedium?.copyWith(
        //             fontWeight: FontWeight.bold,
        //           ),
        //         ),
        //         const SizedBox(height: 12),
        //         Text(
        //           'Keep your health vault updated with the latest information',
        //           style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        //             color: Colors.grey.shade600,
        //           ),
        //           textAlign: TextAlign.center,
        //         ),
        //         const SizedBox(height: 16),
        //         ElevatedButton.icon(
        //           onPressed: () {
        //             // TODO: Navigate to comprehensive health data form
        //             ScaffoldMessenger.of(context).showSnackBar(
        //               const SnackBar(content: Text('Comprehensive health form (coming soon)')),
        //             );
        //           },
        //           icon: const Icon(Icons.edit),
        //           label: const Text('Update Health Data'),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
        // const SizedBox(height: 20),
        _buildHealthRecordsSection(),
      ],
    );
  }

  Widget _buildInfoCard(String title, IconData icon, Color color, List<String> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    if (title == 'Personal Details') {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EditProfilePage()),
                      );
                      if (mounted) {
                        await _loadUserProfile();
                        _showSnack('Profile refreshed');
                      }
                    } else {
                      final mapping = _mapTitleToFieldAndCurrent(title);
                      if (mapping != null) {
                        await _openEditListDialog(
                          fieldKey: mapping.$1,
                          dialogTitle: 'Edit $title',
                          current: mapping.$2,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Editing "$title" not supported yet')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )),
          ],
        ),
      ),
    );
  }
}
