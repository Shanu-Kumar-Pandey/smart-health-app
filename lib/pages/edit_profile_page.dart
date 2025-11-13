import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import '../models/user_profile.dart';
import '../app_theme.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';



class EditProfilePage extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  
  const EditProfilePage({super.key, this.onProfileUpdated});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();

  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _weightController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  // Additional health fields
  final _allergiesController = TextEditingController();
  final _chronicConditionsController = TextEditingController();
  // Insurance field removed per requirement

  String? _selectedGender = "Male";
  bool _isLoading = false;
  bool _isInitialized = false;
  UserProfile? _profile;
  File? _selectedImage;
  String? _currentImageUrl;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickDOB() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _dobController.text =
        "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }

  // Helper to parse comma-separated values into a string list
  List<String> _parseCsvToList(String input) {
    return input
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  }

  void _pickProfilePicture() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette, color: Colors.green),
                title: const Text('Choose Avatar Color'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showAvatarColorPicker();
                },
              ),
              if (_currentImageUrl != null || _selectedImage != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeProfileImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAvatarColorPicker() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Avatar Color'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImage = null;
                  _currentImageUrl = 'avatar_${color.value}';
                });
                Navigator.of(context).pop();
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        String errorMessage = 'Error picking image';
        if (e.toString().contains('MissingPluginException')) {
          errorMessage = 'Image picker not available. Please restart the app after installing dependencies.';
        } else {
          errorMessage = 'Error picking image: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        String errorMessage = 'Error taking photo';
        if (e.toString().contains('MissingPluginException')) {
          errorMessage = 'Camera not available. Please restart the app after installing dependencies.';
        } else {
          errorMessage = 'Error taking photo: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeProfileImage() {
    setState(() {
      _selectedImage = null;
      _currentImageUrl = null;
    });
  }

  // Helper to parse comma-separated values into a string list
  List<String> _parseCsvToList(String input) {
    return input
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await _firebaseService.getUserData();
      setState(() {
        _profile = userProfile;
        _nameController.text = userProfile?.name ?? '';
        _ageController.text = userProfile?.age.toString() ?? '';
        _selectedGender = (userProfile?.gender != null &&
            ['Male', 'Female', 'Other'].contains(userProfile!.gender))
            ? userProfile.gender
            : "Male";
        _bloodGroupController.text = userProfile?.bloodGroup ?? '';
        _weightController.text = userProfile?.weight ?? '';
        _contactController.text = userProfile?.contact ?? '';
        _addressController.text = userProfile?.address ?? '';
        _currentImageUrl = userProfile?.photoURL;
        // Initialize additional fields (comma-separated)
        _allergiesController.text = (userProfile?.allergies ?? const [])
            .whereType<String>()
            .toList()
            .join(', ');
        _chronicConditionsController.text = (userProfile?.chronicConditions ?? const [])
            .whereType<String>()
            .toList()
            .join(', ');
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        String? imageUrl = _currentImageUrl;
        
        // Handle different image scenarios
        if (_selectedImage != null) {
          // Try to upload new image
          try {
            imageUrl = await _firebaseService.uploadProfileImage(_selectedImage!);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image uploaded successfully!'),
                  backgroundColor: Colors.green,
                  // duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (uploadError) {
            // If upload fails, use a placeholder or keep current
            print('Image upload failed: $uploadError');
            if (mounted) {
              String errorMessage = 'Image upload failed. Profile saved without image.';
              
              if (uploadError.toString().contains('Storage bucket not found') || 
                  uploadError.toString().contains('Storage bucket not configured')) {
                errorMessage = 'Firebase Storage not enabled. Please enable it in Firebase Console.';
              } else if (uploadError.toString().contains('Storage access denied')) {
                errorMessage = 'Storage access denied. Please check Firebase Storage rules.';
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Help',
                    textColor: Colors.white,
                    onPressed: () {
                      _showStorageHelpDialog();
                    },
                  ),
                ),
              );
            }
            // Keep the current image URL or set to null if no current image
            imageUrl = _currentImageUrl;
          }
        } else if (_currentImageUrl != null && _currentImageUrl!.startsWith('avatar_')) {
          // Keep avatar color selection
          imageUrl = _currentImageUrl;
        } else if (_currentImageUrl == null && _selectedImage == null) {
          // No image selected and no current image
          imageUrl = null;
        }
        
        final profile = UserProfile(
          name: _nameController.text.trim(),
          age: int.tryParse(_ageController.text) ?? 0,
          gender: _selectedGender ?? "Male",
          bloodGroup: _bloodGroupController.text.trim(),
          weight: _weightController.text.trim(),
          contact: _contactController.text.trim(),
          address: _addressController.text.trim(),
          photoURL: imageUrl,
          allergies: _parseCsvToList(_allergiesController.text),
          chronicConditions: _parseCsvToList(_chronicConditionsController.text),
        );

        await _firebaseService.updateUserProfile(profile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile Updated Successfully"),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Call the callback if provided
          if (widget.onProfileUpdated != null) {
            widget.onProfileUpdated!();
          }
          
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowedGenders = ['Male', 'Female', 'Other'];
    String? genderValue = _selectedGender;
    if (genderValue == null || !allowedGenders.contains(genderValue)) {
      genderValue = "Male";
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text("Edit Profile"),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: _getAvatarColor(),
                      backgroundImage: _getProfileImage(),
                      child: _getProfileImage() == null
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _pickProfilePicture,
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: "Full Name", border: OutlineInputBorder()),
                  validator: (value) =>
                  value!.isEmpty ? "Please enter your name" : null,
                ),
                const SizedBox(height: 16),
                // TextFormField(
                //   controller: _dobController,
                //   readOnly: true,
                //   onTap: _pickDOB,
                //   decoration: const InputDecoration(
                //     labelText: "Date of Birth",
                //     border: OutlineInputBorder(),
                //     suffixIcon: Icon(Icons.calendar_today),
                //   ),
                // ),
                // const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: "Age", border: OutlineInputBorder()),
                  validator: (value) =>
                  value!.isEmpty ? "Please enter your age" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bloodGroupController,
                  decoration: const InputDecoration(
                      labelText: "Blood Group", border: OutlineInputBorder()),
                  validator: (value) =>
                  value!.isEmpty ? "Please enter your blood group" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: "Weight (kg)", border: OutlineInputBorder()),
                  validator: (value) =>
                  value!.isEmpty ? "Please enter your weight" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: genderValue,
                  hint: const Text("Select Gender"),
                  decoration: const InputDecoration(
                      labelText: "Gender", border: OutlineInputBorder()),
                  items: allowedGenders
                      .map((gender) => DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                  validator: (value) =>
                  value == null || value.isEmpty
                      ? "Please select your gender"
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: "Contact Number",
                      border: OutlineInputBorder()),
                  validator: (value) =>
                  value!.isEmpty ? "Please enter contact number" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: "Address", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                // Additional health fields (comma-separated)
                TextFormField(
                  controller: _allergiesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Allergies (comma-separated)',
                    hintText: 'e.g., Penicillin, Dust, Pollen',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _chronicConditionsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Chronic Conditions (comma-separated)',
                    hintText: 'e.g., Diabetes, Hypertension',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Insurance input removed
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Save Profile",
                        style:
                        TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    } else if (_currentImageUrl != null && 
               _currentImageUrl!.isNotEmpty && 
               !_currentImageUrl!.startsWith('avatar_')) {
      return NetworkImage(_currentImageUrl!);
    }
    return null;
  }

  Color _getAvatarColor() {
    if (_currentImageUrl != null && _currentImageUrl!.startsWith('avatar_')) {
      final colorValue = _currentImageUrl!.replaceFirst('avatar_', '');
      try {
        return Color(int.parse(colorValue));
      } catch (e) {
        return AppTheme.primaryBlue; // Use theme color from AppTheme
      }
    }
    return Colors.grey.shade300;
  }

  void _showStorageHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firebase Storage Setup Required'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To upload images, you need to enable Firebase Storage:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('1. Go to Firebase Console'),
              Text('2. Select your project: smart_health_companion_app-2b0e0'),
              Text('3. Click "Storage" → "Get started"'),
              Text('4. Choose "Start in test mode"'),
              Text('5. Select a location'),
              Text('6. Click "Done"'),
              SizedBox(height: 12),
              Text(
                'Alternative: Use Avatar Colors',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              Text('Tap the camera icon and choose "Choose Avatar Color" for immediate use.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
