import 'package:flutter/material.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import '../../data/pet_service.dart';
import 'pet_edit_field_screen.dart';
import 'pet_edit_photo_screen.dart';

/// New edit flow:
/// - Overview page with all fields
/// - Each field has an Edit button
/// - Editing opens a dedicated page and saves there
class PetEditOverviewScreen extends StatefulWidget {
  final int petId;
  const PetEditOverviewScreen({super.key, required this.petId});

  @override
  State<PetEditOverviewScreen> createState() => _PetEditOverviewScreenState();
}

class _PetEditOverviewScreenState extends State<PetEditOverviewScreen> {
  final _service = PetService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _pet = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pet = await _service.getPet(widget.petId);
      setState(() {
        _pet = pet;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _value(String key) {
    final v = _pet[key];
    if (v == null) return '-';
    if (key == 'dateOfBirth') {
      try {
        final d = DateTime.parse(v.toString());
        return "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
      } catch (_) {
        return '-';
      }
    }
    return v.toString().isEmpty ? '-' : v.toString();
  }

  String _petPhotoUrl() {
    final pic = _pet['profilePic'];
    if (pic is Map) {
      final u = pic['url']?.toString();
      if (u != null && u.trim().isNotEmpty) return u;
    }
    final u2 = _pet['photoUrl']?.toString();
    return (u2 ?? '').trim();
  }

  Future<void> _editPhoto() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PetEditPhotoScreen(
          petId: widget.petId,
          currentPhotoUrl: _petPhotoUrl(),
        ),
      ),
    );
    if (ok == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    }
  }

  Future<void> _edit({
    required String label,
    required String fieldKey,
    EditFieldType type = EditFieldType.text,
  }) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PetEditFieldScreen(
          petId: widget.petId,
          label: label,
          fieldKey: fieldKey,
          initialValue: _pet[fieldKey]?.toString() ?? '',
          type: type,
        ),
      ),
    );

    if (ok == true) {
      await _load();
      if (mounted) {
        // bubble refresh to previous screen
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Pet'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              children: [
                _tile(
                  'Profile Photo',
                  _petPhotoUrl().isEmpty ? '-' : 'Updated',
                  _editPhoto,
                ),
                _tile(
                  'Name',
                  _value('name'),
                  () => _edit(label: 'Name', fieldKey: 'name'),
                ),
                _tile(
                  'Gender',
                  _value('sex'),
                  () => _edit(
                    label: 'Gender',
                    fieldKey: 'sex',
                    type: EditFieldType.gender,
                  ),
                ),
                _tile(
                  'Birthdate',
                  _value('dateOfBirth'),
                  () => _edit(
                    label: 'Birthdate',
                    fieldKey: 'dateOfBirth',
                    type: EditFieldType.date,
                  ),
                ),
                _tile(
                  'Microchip Number',
                  _value('microchipNumber'),
                  () => _edit(
                    label: 'Microchip Number',
                    fieldKey: 'microchipNumber',
                  ),
                ),
                _tile(
                  'Food Habits',
                  _value('foodHabits'),
                  () => _edit(
                    label: 'Food Habits',
                    fieldKey: 'foodHabits',
                    type: EditFieldType.multiline,
                  ),
                ),
                _tile(
                  'Health Disorders',
                  _value('healthDisorders'),
                  () => _edit(
                    label: 'Health Disorders',
                    fieldKey: 'healthDisorders',
                    type: EditFieldType.multiline,
                  ),
                ),
                _tile(
                  'Notes',
                  _value('notes'),
                  () => _edit(
                    label: 'Notes',
                    fieldKey: 'notes',
                    type: EditFieldType.multiline,
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(t.deletePet),
                          content: Text(t.deletePetConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(t.cancel),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(t.delete),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        try {
                          await _service.deletePet(widget.petId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(t.deleted)));
                          Navigator.pop(context, true);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(t.deletePet),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
    );
  }

  Widget _tile(String label, String value, VoidCallback onEdit) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
      trailing: TextButton(onPressed: onEdit, child: const Text('Edit')),
    );
  }
}
