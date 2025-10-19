import 'package:flutter/material.dart';

class UpcomingEventTile extends StatelessWidget {
  const UpcomingEventTile({
    super.key,
    required this.title,
    required this.date,
    this.location,
    this.onTap,
  });

  final String title;
  final String date;
  final String? location;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(title),
      subtitle: Text(
        location == null ? date : '$date · $location',
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
