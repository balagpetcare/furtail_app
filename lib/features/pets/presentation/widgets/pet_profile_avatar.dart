import 'dart:io';
import 'package:flutter/material.dart';

class PetProfileAvatar extends StatelessWidget {
  final File? file;
  final double size;

  const PetProfileAvatar({super.key, required this.file, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: file == null ? null : FileImage(file!),
      child: file == null
          ? Icon(Icons.pets, size: size * 0.45, color: Colors.grey.shade600)
          : null,
    );
  }
}
