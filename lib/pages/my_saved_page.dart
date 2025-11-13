import 'package:flutter/material.dart';

class MySavedPage extends StatelessWidget {
  const MySavedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Saved')),
      body: const Center(child: Text('My Saved Items')),
    );
  }
}
