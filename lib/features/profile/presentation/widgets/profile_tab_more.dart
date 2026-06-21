import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/typography.dart';
/// More tab: extra options + privacy controls.
/// If [openEditorDirectly] is true, it renders the "About editor" list style.
class ProfileTabMore extends StatelessWidget {
  final bool openEditorDirectly;
  const ProfileTabMore({super.key, this.openEditorDirectly = false});

  @override
  Widget build(BuildContext context) {
    if (openEditorDirectly) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Edit About Details', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _editTile(context, 'Education'),
          _editTile(context, 'Place Live'),
          _editTile(context, 'Fans and Friends'),
          _editTile(context, 'From'),
          _editTile(context, 'Profile Type'),
          _editTile(context, 'Work Status'),
          _editTile(context, 'Religious Status'),
          _editTile(context, 'Gender'),
          _editTile(context, 'Birthdate'),
          _editTile(context, 'Marital Status'),
          const SizedBox(height: 20),
          const Text('Note: Wire each field to its own edit page with Save.', style: TextStyle(color: Colors.black54)),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('More Options', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Options'),
          items: const [
            DropdownMenuItem(value: 'settings', child: Text('Settings')),
            DropdownMenuItem(value: 'privacy', child: Text('Privacy')),
            DropdownMenuItem(value: 'report', child: Text('Report')),
          ],
          onChanged: (_) {},
        ),
        const SizedBox(height: 16),

        const Text('Privacy Controls', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _switchTile('Private Profile', false),
        _switchTile('Hide Birthdate', false),
        _switchTile('Hide Gender', false),
        _switchTile('Hide Religion', false),
        const SizedBox(height: 16),

        const Text('Mutual Connections', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8FC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x11000000)),
          ),
          child: const Text('TODO: Show mutual friends/followers when viewing other users.'),
        ),
      ],
    );
  }

  Widget _switchTile(String title, bool value) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: (_) {},
    );
  }

  Widget _editTile(BuildContext context, String label) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: const Text('Not set'),
      trailing: TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Open edit page for $label (TODO).')),
          );
        },
        child: const Text('Edit'),
      ),
    );
  }
}
