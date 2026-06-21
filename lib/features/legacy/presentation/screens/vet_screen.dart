import 'package:flutter/material.dart';

class VetScreen extends StatelessWidget {
  const VetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Find a Vet")), // ব্যাক বাটন অটোমেটিক আসবে
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text("Dr. Vet Name ${index + 1}"),
          subtitle: const Text("Specialist in Dogs & Cats"),
          trailing: ElevatedButton(onPressed: () {}, child: const Text("Book")),
        ),
      ),
    );
  }
}