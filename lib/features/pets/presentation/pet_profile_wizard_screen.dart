import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../ui/components/inputs/app_text_field.dart';
import '../../../ui/components/inputs/app_dropdown.dart';
import '../../../ui/components/app_date_field.dart';
import '../../../ui/components/feedback/app_snackbar.dart';

import 'cubit/pet_form_cubit.dart';
import 'cubit/pet_form_state.dart';
import 'widgets/pet_step_header.dart';

class PetProfileWizardScreen extends ConsumerStatefulWidget {
  final int? petId;
  const PetProfileWizardScreen({super.key, this.petId});

  @override
  ConsumerState<PetProfileWizardScreen> createState() =>
      _PetProfileWizardScreenState();
}

class _PetProfileWizardScreenState
    extends ConsumerState<PetProfileWizardScreen> {
  static const _titles = <String>['Basic', 'Photo', 'Details', 'Preview'];

  // Controllers are required for your AppTextField implementation
  late final TextEditingController _nameCtrl;
  late final TextEditingController _microCtrl;
  late final TextEditingController _foodCtrl;
  late final TextEditingController _healthCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _microCtrl = TextEditingController();
    _foodCtrl = TextEditingController();
    _healthCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _microCtrl.dispose();
    _foodCtrl.dispose();
    _healthCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _dateText(DateTime? d) =>
      d == null ? 'Select date' : d.toIso8601String().split('T').first;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petFormProvider(widget.petId));
    final ctrl = ref.read(petFormProvider(widget.petId).notifier);

    // Sync controllers with state (handles initial load when editing)
    if (_nameCtrl.text != state.name) _nameCtrl.text = state.name;
    if (_microCtrl.text != state.microchipNumber)
      _microCtrl.text = state.microchipNumber;
    if (_foodCtrl.text != state.foodHabits) _foodCtrl.text = state.foodHabits;
    if (_healthCtrl.text != state.healthDisorders)
      _healthCtrl.text = state.healthDisorders;
    if (_notesCtrl.text != state.notes) _notesCtrl.text = state.notes;

    ref.listen<PetFormState>(petFormProvider(widget.petId), (prev, next) {
      if (next.error != null &&
          next.error != prev?.error &&
          next.error!.isNotEmpty) {
        AppSnackBar.show(context, next.error!, success: false);
      }
      if (next.success && prev?.success != true) {
        Navigator.of(context).pop(true);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(state.editMode ? 'Edit Pet' : 'Register New Pet'),
      ),
      body: SafeArea(
        child: state.loading && state.editMode && state.step == 0
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  PetStepHeader(current: state.step, titles: _titles),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _stepBody(context, state, ctrl),
                    ),
                  ),
                  _Footer(state: state, ctrl: ctrl),
                ],
              ),
      ),
    );
  }

  Widget _stepBody(
    BuildContext context,
    PetFormState state,
    PetFormController ctrl,
  ) {
    switch (state.step) {
      case 0:
        return _stepBasic(context, state, ctrl);
      case 1:
        return _stepPhotoOnly(context, state, ctrl);
      case 2:
        return _stepDetails(context, state, ctrl);
      default:
        return _stepPreview(context, state, ctrl);
    }
  }

  Widget _stepBasic(
    BuildContext context,
    PetFormState state,
    PetFormController ctrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Pet Name',
          controller: _nameCtrl, // Replaced initialValue with controller
          onChanged: ctrl.setName,
        ),
        const SizedBox(height: 12),
        AppDropdown<int>(
          label: 'Animal Type',
          value: state.animalTypeId,
          items: state.animalTypes
              .map(
                (m) => DropdownMenuItem<int>(
                  value: m['id'] as int?,
                  child: Text((m['name'] ?? '').toString()),
                ),
              )
              .toList(),
          onChanged: (v) => ctrl.setAnimalType(v),
        ),
        const SizedBox(height: 12),
        AppDropdown<int>(
          label: 'Breed (optional)',
          value: state.breedId,
          items: state.breeds
              .map(
                (m) => DropdownMenuItem<int>(
                  value: m['id'] as int?,
                  child: Text((m['name'] ?? '').toString()),
                ),
              )
              .toList(),
          onChanged: (v) => ctrl.setBreed(v),
        ),
        const SizedBox(height: 12),
        AppDateField(
          label: 'Date of birth (optional)',
          valueText: _dateText(state.dob),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  state.dob ?? DateTime(now.year - 1, now.month, now.day),
              firstDate: DateTime(2000),
              lastDate: now,
            );
            if (picked != null) ctrl.setDob(picked);
          },
        ),
        const SizedBox(height: 12),
        AppDropdown<int>(
          label: 'Age (years) (optional)',
          value: state.ageYears,
          items: List.generate(
            31,
            (i) => DropdownMenuItem<int>(value: i, child: Text('$i')),
          ),
          onChanged: (v) => ctrl.setAgeYears(v),
        ),
        const SizedBox(height: 10),
        if (state.dob != null || state.ageYears != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x11000000)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Preview', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if (state.dob != null) Text('DOB: ${_dateText(state.dob)}'),
                if (state.ageYears != null) Text('Age: ${state.ageYears} years'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stepPhotoOnly(
    BuildContext context,
    PetFormState state,
    PetFormController ctrl,
  ) {
    final photoFile = state.photoFile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Center(
          child: InkWell(
            onTap: () async {
              final x = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 80,
              );
              if (x != null) ctrl.setPhoto(x);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: photoFile == null
                  ? const Center(child: Icon(Icons.add_a_photo, size: 42))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(photoFile, fit: BoxFit.cover),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepDetails(
    BuildContext context,
    PetFormState state,
    PetFormController ctrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdown<String>(
          label: 'Gender',
          value: state.sex,
          items: const [
            DropdownMenuItem(value: 'MALE', child: Text('Male')),
            DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
            DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown')),
          ],
          onChanged: (v) => ctrl.setSex(v ?? 'UNKNOWN'),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Microchip Number (optional)',
          controller: _microCtrl, // Replaced initialValue
          onChanged: ctrl.setMicrochip,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: state.isRescue,
          onChanged: ctrl.setRescue,
          title: const Text('Rescue Pet'),
        ),
        SwitchListTile(
          value: state.isNeutered,
          onChanged: ctrl.setNeutered,
          title: const Text('Neutered'),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Food Habits (optional)',
          controller: _foodCtrl, // Replaced initialValue
          onChanged: ctrl.setFood,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Health Disorders (optional)',
          controller: _healthCtrl, // Replaced initialValue
          onChanged: ctrl.setHealth,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Notes (optional)',
          controller: _notesCtrl, // Replaced initialValue
          onChanged: ctrl.setNotes,
          maxLines: 3,
        ),
      ],
    );
  }

  String _lookupName(List<Map<String, dynamic>> list, int? id) {
    if (id == null) return '';
    final hit = list.where((e) => e['id'] == id).toList();
    return hit.isEmpty ? '' : (hit.first['name'] ?? '').toString();
  }

  Widget _stepPreview(
    BuildContext context,
    PetFormState state,
    PetFormController ctrl,
  ) {
    final typeName = _lookupName(state.animalTypes, state.animalTypeId);
    final breedName = _lookupName(state.breeds, state.breedId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _previewRow('Name', state.name),
                _previewRow('Animal Type', typeName),
                _previewRow('Breed', breedName),
                _previewRow('DOB', _dateText(state.dob)),
                _previewRow('Gender', state.sex),
                _previewRow('Rescue', state.isRescue ? 'Yes' : 'No'),
                _previewRow('Neutered', state.isNeutered ? 'Yes' : 'No'),
              ],
            ),
          ),
        ),
        if (state.photoFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  state.photoFile!,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$label: ${value.isEmpty ? '-' : value}'),
    );
  }
}

class _Footer extends StatelessWidget {
  final PetFormState state;
  final PetFormController ctrl;

  const _Footer({required this.state, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isLast = state.step >= 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (state.step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: state.loading ? null : () => ctrl.back(),
                child: const Text('Back'),
              ),
            ),
          if (state.step > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: state.loading
                  ? null
                  : () {
                      if (!isLast) {
                        ctrl.next();
                      } else {
                        ctrl.submit();
                      }
                    },
              child: Text(
                isLast ? (state.editMode ? 'Save' : 'Create') : 'Next',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
