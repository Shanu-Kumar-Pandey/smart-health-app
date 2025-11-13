import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = <Map<String, String>>[
      {
        'q': 'How do I book an appointment?',
        'a': 'Open Home > Appointment and choose a date, time, and reason. Your appointment will appear under Profile > See the Details.'
      },
      {
        'q': 'How can I update my profile?',
        'a': 'Go to Profile > Edit Profile. Change your information and tap Save.'
      },
      {
        'q': 'Is my data secure?',
        'a': 'We use Firebase Authentication and Firestore. Data is transmitted over HTTPS and stored securely in Firebase.'
      },
      {
        'q': 'What reminders can I set?',
        'a': 'You can set medication, hydration, exercise and sleep reminders in the Reminder tab.'
      },
      {
        'q': 'I forgot my password. What should I do?',
        'a': 'On the Login screen, tap “Forgot Password” to receive a reset link in your email.'
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FAQs')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = faqs[index];
          return ExpansionTile(
            title: Text(item['q']!),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(item['a']!),
              ),
            ],
          );
        },
        separatorBuilder: (context, _) => const SizedBox(height: 8),
        itemCount: faqs.length,
      ),
    );
  }
}
