import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  // কনস্ট্রাক্টরে কোনো required ডাটা রাখবেন না
  const DashboardScreen({super.key}); 

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String userName = "Loading...";
  String userEmail = "";

  @override
  void initState() {
    super.initState();
    _loadUserData(); // পেজ চালু হলেই ডাটা লোড হবে
  }

  // মেমোরি থেকে ডাটা আনার ফাংশন
  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      // Login এর সময় সেভ করা ডাটাগুলো এখানে ভেরিয়েবলে সেট করছি
      userName = prefs.getString('userName') ?? "User Name"; 
      userEmail = prefs.getString('userEmail') ?? "email@example.com";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Dashboard")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 20),
            Text(userName, style: context.appText.headlineMedium!.copyWith(fontWeight: FontWeight.bold)),
            Text(userEmail, style: const TextStyle(color: Colors.grey)),
            
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Edit Profile Logic
              },
              child: const Text("Edit Profile"),
            )
          ],
        ),
      ),
    );
  }
}