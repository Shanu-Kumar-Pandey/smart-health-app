import 'package:flutter/material.dart';

class SearchableTab extends StatefulWidget {
  const SearchableTab({super.key});

  @override
  State<SearchableTab> createState() => _SearchableTabState();
}

class _SearchableTabState extends State<SearchableTab> {
  String searchQuery = "";

  // Health-related sample data (title -> description)
  final List<Map<String, String>> healthItems = [
    {
      'title': 'High Blood Pressure',
      'desc': 'Understand causes, symptoms, and lifestyle changes to manage hypertension.'
    },
    {
      'title': 'Diabetes Management',
      'desc': 'Track glucose, diet, and exercise to manage type 1 or type 2 diabetes.'
    },
    {
      'title': 'Heart Health Tips',
      'desc': 'Daily practices to keep your heart strong and healthy.'
    },
    {
      'title': 'Mental Health Awareness',
      'desc': 'Recognize signs of stress, anxiety, and depression, and ways to cope.'
    },
    {
      'title': 'COVID-19 Precautions',
      'desc': 'Latest safety measures to protect yourself and others.'
    },
    {
      'title': 'Daily Exercise Routine',
      'desc': 'Simple routines to improve strength, flexibility, and endurance.'
    },
    {
      'title': 'Healthy Diet Plan',
      'desc': 'Balanced nutrition guidelines for everyday health.'
    },
    {
      'title': 'Yoga for Flexibility',
      'desc': 'Beginner-friendly yoga poses to increase flexibility and balance.'
    },
    {
      'title': 'Stress Reduction Techniques',
      'desc': 'Breathing, mindfulness, and time management strategies.'
    },
    {
      'title': 'Immunity Boosting Foods',
      'desc': 'Nutrient-dense foods to support your immune system.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final List<Map<String, String>> filteredItems = healthItems
        .where((item) => item['title']!
            .toLowerCase()
            .contains(searchQuery.toLowerCase()))
        .toList();

    return Container(
      color: colorScheme.background,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              cursorColor: colorScheme.primary,
              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search health topics...',
                hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: colorScheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        'No matching health info found.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.health_and_safety, color: colorScheme.primary),
                            title: _highlightQuery(item['title']!, searchQuery),
                            subtitle: Text(
                              item['desc']!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightQuery(String text, String query) {
    if (query.isEmpty) return Text(text);
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);
    if (startIndex == -1) return Text(text);
    final endIndex = startIndex + query.length;
    return RichText(
      text: TextSpan(
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }
}
