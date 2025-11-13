import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/user_profile.dart';

class ProfileDetailsPage extends StatelessWidget {
  const ProfileDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService service = FirebaseService();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Details')),
      body: FutureBuilder<UserProfile?>(
        future: service.getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('No profile data found'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _tile('Name', profile.name ?? ''),
              _tile('Age', profile.age?.toString() ?? ''),
              _tile('Gender', profile.gender ?? ''),
              _tile('Blood Group', profile.bloodGroup ?? ''),
              _tile('Weight', profile.weight ?? ''),
              _tile('Contact', profile.contact ?? ''),
              _tile('Email', profile.email ?? ''),
              _tile('Address', profile.address ?? ''),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label),
        subtitle: Text(value.isEmpty ? '-' : value),
      ),
    );
  }
}


