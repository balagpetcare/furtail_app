import 'package:flutter/material.dart';
import 'vet_screen.dart';
import 'donation_screen.dart';
import 'adoption_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Services"), automaticallyImplyLeading: false),
      body: ListView(
        children: [
          _buildServiceTile(context, "Veterinary Doctors", Icons.medical_services, const VetScreen()),
          _buildServiceTile(context, "Donations", Icons.favorite, const DonationScreen()),
          _buildServiceTile(context, "Adoption Center", Icons.pets, const AdoptionScreen()),
          _buildServiceTile(context, "Pet Training", Icons.sports_baseball, null), // null মানে পেজ তৈরি হয়নি
        ],
      ),
    );
  }

  Widget _buildServiceTile(BuildContext context, String title, IconData icon, Widget? page) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        if (page != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => page));
        }
      },
    );
  }
}