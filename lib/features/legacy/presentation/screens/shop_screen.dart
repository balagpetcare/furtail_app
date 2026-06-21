import 'package:flutter/material.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pet Shop"), automaticallyImplyLeading: false), // ব্যাক বাটন লুকানো কারণ এটি ট্যাবে থাকবে
      body: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Card(
            child: Column(
              children: [
                Expanded(
                  child: Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.shopping_bag, size: 40))),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("Product Item ${index + 1}"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}