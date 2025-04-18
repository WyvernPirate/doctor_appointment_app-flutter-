// lib/widgets/doctor_list_item.dart
import 'package:flutter/material.dart';
import '../models/doctor.dart';

class DoctorListItem extends StatelessWidget {
  final Doctor doctor;

  const DoctorListItem({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.blueGrey[50],
          backgroundImage: doctor.imageUrl.isNotEmpty
              ? NetworkImage(doctor.imageUrl)
              : null,
          onBackgroundImageError: doctor.imageUrl.isNotEmpty ? (_, __) {} : null,
          child: doctor.imageUrl.isEmpty
              ? Icon(Icons.person, color: Colors.blueGrey[300])
              : null,
        ),
        title: Text(
          doctor.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          doctor.specialty,
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rate_rounded, color: Colors.amber[600], size: 18),
            const SizedBox(width: 4),
            Text(
              doctor.rating.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        onTap: () {
          print('Tapped on ${doctor.name} (ID: ${doctor.id})');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected ${doctor.name}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}
