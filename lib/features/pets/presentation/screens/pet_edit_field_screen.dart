import 'package:flutter/material.dart';

import '../../data/pet_service.dart';

enum EditFieldType { text, multiline, date, gender }

/// Edit a single pet field and save from this screen.
class PetEditFieldScreen extends StatefulWidget {
  final int petId;
  final String label;
  final String fieldKey;
  final String initialValue;
  final EditFieldType type;

  const PetEditFieldScreen({
    super.key,
    required this.petId,
    required this.label,
    required this.fieldKey,
    required this.initialValue,
    required this.type,
  });

  @override
  State<PetEditFieldScreen> createState() => _PetEditFieldScreenState();
}

class _PetEditFieldScreenState extends State<PetEditFieldScreen> {
  final _service = PetService();
  late final TextEditingController _c;
  DateTime? _selectedDate;
  String _gender = 'MALE';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initialValue);
    if (widget.type == EditFieldType.date) {
      _selectedDate = _tryParse(widget.initialValue);
    }
    if (widget.type == EditFieldType.gender) {
      final v = widget.initialValue.trim().toUpperCase();
      _gender = (v == 'FEMALE') ? 'FEMALE' : 'MALE';
    }
  }

  DateTime? _tryParse(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? DateTime(now.year - 1, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select Date',
    );

    if (d != null) {
      // ✅ requirement: show selected date immediately
      setState(() => _selectedDate = d);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      dynamic value;
      if (widget.type == EditFieldType.date) {
        if (_selectedDate == null) throw Exception('Please select a date');
        value = _selectedDate!.toIso8601String();
      } else if (widget.type == EditFieldType.gender) {
        value = _gender; // API expects MALE/FEMALE
      } else {
        value = _c.text.trim();
      }

      await _service.updatePet(widget.petId, {widget.fieldKey: value});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _hasUnsavedChanges {
    if (widget.type == EditFieldType.date) {
      final initialDate = _tryParse(widget.initialValue);
      return _selectedDate != initialDate;
    } else if (widget.type == EditFieldType.gender) {
      final initialGender = (widget.initialValue.trim().toUpperCase() == 'FEMALE') ? 'FEMALE' : 'MALE';
      return _gender != initialGender;
    } else {
      return _c.text != widget.initialValue;
    }
  }

  Widget _genderPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Gender', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Male'),
                selected: _gender == 'MALE',
                onSelected: (_) => setState(() => _gender = 'MALE'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Text('Female'),
                selected: _gender == 'FEMALE',
                onSelected: (_) => setState(() => _gender = 'FEMALE'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDate = widget.type == EditFieldType.date;
    final isGender = widget.type == EditFieldType.gender;
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.label}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_saving) return;
          if (!_hasUnsavedChanges) {
            Navigator.pop(context);
            return;
          }
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text('Are you sure you want to discard your changes?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isDate)
              ListTile(
                title: const Text('Selected Date'),
                subtitle: Text(
                  _selectedDate == null
                      ? 'Not selected'
                      : "${_selectedDate!.day.toString().padLeft(2, '0')}-"
                        "${_selectedDate!.month.toString().padLeft(2, '0')}-"
                        "${_selectedDate!.year}",
                ),
                trailing: OutlinedButton(
                  onPressed: _pickDate,
                  child: const Text('Pick'),
                ),
              )
            else if (isGender)
              _genderPicker()
            else
              TextField(
                controller: _c,
                maxLines: widget.type == EditFieldType.multiline ? 6 : 1,
                decoration: InputDecoration(
                  labelText: widget.label,
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
