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

class PetProfileWizardScreen extends ConsumerStatefulWidget {
  final int? petId;
  const PetProfileWizardScreen({super.key, this.petId});

  @override
  ConsumerState<PetProfileWizardScreen> createState() =>
      _PetProfileWizardScreenState();
}

class _PetProfileWizardScreenState
    extends ConsumerState<PetProfileWizardScreen> {
  static const _titles = <String>[
    'Basic Info',
    'Appearance',
    'Health',
    'Lifestyle',
    'Public Profile',
    'Review',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _microCtrl;
  late final TextEditingController _foodCtrl;
  late final TextEditingController _healthCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _bloodTypeCtrl;
  late final TextEditingController _allergiesCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _microCtrl = TextEditingController();
    _foodCtrl = TextEditingController();
    _healthCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _bloodTypeCtrl = TextEditingController();
    _allergiesCtrl = TextEditingController();
    _slugCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _microCtrl, _foodCtrl, _healthCtrl, _notesCtrl,
      _bloodTypeCtrl, _allergiesCtrl, _slugCtrl, _bioCtrl, _weightCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers(PetFormState s) {
    void sync(TextEditingController c, String v) {
      if (c.text != v) c.text = v;
    }
    sync(_nameCtrl, s.name);
    sync(_microCtrl, s.microchipNumber);
    sync(_foodCtrl, s.foodHabits);
    sync(_healthCtrl, s.healthDisorders);
    sync(_notesCtrl, s.notes);
    sync(_bloodTypeCtrl, s.bloodType ?? '');
    sync(_allergiesCtrl, s.allergiesText);
    sync(_slugCtrl, s.slug);
    sync(_bioCtrl, s.bio);
    sync(_weightCtrl, s.weightKg != null ? s.weightKg!.toString() : '');
  }

  String _dateText(DateTime? d) =>
      d == null ? 'Select date' : d.toIso8601String().split('T').first;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petFormProvider(widget.petId));
    final ctrl = ref.read(petFormProvider(widget.petId).notifier);

    _syncControllers(state);

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final hasChanges = state.name.trim().isNotEmpty || state.step > 0;
        if (!hasChanges) {
          if (context.mounted) Navigator.of(context).pop();
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Your pet registration progress will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Discard', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          state.editMode ? 'Edit Pet' : 'Register New Pet',
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      body: SafeArea(
        child: state.loading && state.step == 0 && state.animalTypes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : (state.error != null && state.step == 0 && state.animalTypes.isEmpty)
                ? _ErrorRetry(
                    message: state.error!,
                    onRetry: () => ctrl.init(),
                  )
                : Column(
                children: [
                  _WizardProgress(step: state.step, titles: _titles),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: _stepBody(context, state, ctrl),
                    ),
                  ),
                  _WizardFooter(state: state, ctrl: ctrl),
                ],
              ),
      ),
      ),
    );
  }

  Widget _stepBody(BuildContext ctx, PetFormState s, PetFormController ctrl) {
    switch (s.step) {
      case 0:
        return _step1Basic(ctx, s, ctrl);
      case 1:
        return _step2Appearance(ctx, s, ctrl);
      case 2:
        return _step3Health(ctx, s, ctrl);
      case 3:
        return _step4Lifestyle(ctx, s, ctrl);
      case 4:
        return _step5PublicProfile(ctx, s, ctrl);
      default:
        return _step6Review(ctx, s, ctrl);
    }
  }

  // ── Step 1: Basic Info ────────────────────────────────────────────────────

  Widget _step1Basic(BuildContext ctx, PetFormState s, PetFormController ctrl) {
    return _WizardCard(
      title: 'Basic Information',
      subtitle: 'Tell us about your pet',
      children: [
        _PhotoPicker(
          file: s.photoFile,
          onPick: () async {
            final x = await ImagePicker()
                .pickImage(source: ImageSource.gallery, imageQuality: 80);
            if (x != null) ctrl.setPhoto(x);
          },
          onRemove: ctrl.removePhoto,
        ),
        const SizedBox(height: 20),
        _FieldLabel('Pet Name', required: true),
        AppTextField(
          label: 'e.g. Buddy, Luna',
          controller: _nameCtrl,
          onChanged: ctrl.setName,
        ),
        const SizedBox(height: 14),
        _FieldLabel('Animal Type', required: true),
        AppDropdown<int>(
          label: 'Select type',
          value: s.animalTypeId,
          items: s.animalTypes
              .map((m) => DropdownMenuItem<int>(
                    value: m['id'] as int?,
                    child: Text((m['name'] ?? '').toString()),
                  ))
              .toList(),
          onChanged: (v) => ctrl.setAnimalType(v),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Breed'),
        AppDropdown<int>(
          label: 'Select breed (optional)',
          value: s.breedId,
          items: s.breeds
              .map((m) => DropdownMenuItem<int>(
                    value: m['id'] as int?,
                    child: Text((m['name'] ?? '').toString()),
                  ))
              .toList(),
          onChanged: (v) => ctrl.setBreed(v),
        ),
        if (s.breedId == null) ...[
          const SizedBox(height: 10),
          AppTextField(
            label: 'Custom breed name (if not listed)',
            controller: TextEditingController(text: s.customBreedText ?? ''),
            onChanged: ctrl.setCustomBreed,
          ),
        ],
        const SizedBox(height: 14),
        _FieldLabel('Sex', required: true),
        AppDropdown<String>(
          label: 'Select sex',
          value: s.sex,
          items: const [
            DropdownMenuItem(value: 'MALE', child: Text('Male')),
            DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
            DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown')),
          ],
          onChanged: (v) => ctrl.setSex(v ?? 'UNKNOWN'),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Date of Birth'),
        AppDateField(
          label: _dateText(s.dob),
          valueText: _dateText(s.dob),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: s.dob ?? DateTime(now.year - 1, now.month, now.day),
              firstDate: DateTime(2000),
              lastDate: now,
            );
            if (picked != null) ctrl.setDob(picked);
          },
        ),
        if (s.dob == null) ...[
          const SizedBox(height: 10),
          AppDropdown<int>(
            label: 'Estimated age (years)',
            value: s.ageYears,
            items: List.generate(
              31,
              (i) => DropdownMenuItem<int>(value: i, child: Text('$i years')),
            ),
            onChanged: (v) => ctrl.setAgeYears(v),
          ),
        ],
      ],
    );
  }

  // ── Step 2: Appearance ────────────────────────────────────────────────────

  Widget _step2Appearance(
      BuildContext ctx, PetFormState s, PetFormController ctrl) {
    return _WizardCard(
      title: 'Appearance',
      subtitle: 'Physical characteristics',
      children: [
        _InfoBanner(
          'These optional details help others identify and appreciate your pet better.',
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Color (e.g. Golden, Black & White)',
          controller:
              TextEditingController(text: s.customColorText ?? ''),
          onChanged: ctrl.setCustomColor,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Weight in kg (optional)',
          controller: _weightCtrl,
          onChanged: (v) =>
              ctrl.setWeight(double.tryParse(v)),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  // ── Step 3: Health ────────────────────────────────────────────────────────

  Widget _step3Health(
      BuildContext ctx, PetFormState s, PetFormController ctrl) {
    return _WizardCard(
      title: 'Health Information',
      subtitle: 'Medical and care details',
      children: [
        _SwitchTile(
          title: 'Neutered / Spayed',
          subtitle: 'Has your pet been neutered or spayed?',
          value: s.isNeutered,
          onChanged: ctrl.setNeutered,
        ),
        const SizedBox(height: 10),
        _FieldLabel('Microchip Number'),
        AppTextField(
          label: 'Microchip ID (optional)',
          controller: _microCtrl,
          onChanged: ctrl.setMicrochip,
        ),
        const SizedBox(height: 14),
        _FieldLabel('Blood Type'),
        AppTextField(
          label: 'e.g. DEA 1.1, A, B (optional)',
          controller: _bloodTypeCtrl,
          onChanged: ctrl.setBloodType,
        ),
        const SizedBox(height: 14),
        _FieldLabel('Allergies'),
        AppTextField(
          label: 'Comma-separated, e.g. Pollen, Chicken',
          controller: _allergiesCtrl,
          onChanged: ctrl.setAllergies,
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        _FieldLabel('Existing Health Disorders'),
        AppTextField(
          label: 'Any known conditions or diseases',
          controller: _healthCtrl,
          onChanged: ctrl.setHealth,
          maxLines: 3,
        ),
      ],
    );
  }

  // ── Step 4: Lifestyle ─────────────────────────────────────────────────────

  Widget _step4Lifestyle(
      BuildContext ctx, PetFormState s, PetFormController ctrl) {
    return _WizardCard(
      title: 'Lifestyle & Care',
      subtitle: 'Daily habits and preferences',
      children: [
        _SwitchTile(
          title: 'Rescue / Adopted Pet',
          subtitle: 'This pet was rescued or adopted',
          value: s.isRescue,
          onChanged: ctrl.setRescue,
        ),
        const SizedBox(height: 14),
        _FieldLabel('Food Habits'),
        AppTextField(
          label: 'e.g. Dry kibble, Raw diet, Vegetarian',
          controller: _foodCtrl,
          onChanged: ctrl.setFood,
          maxLines: 3,
        ),
        const SizedBox(height: 14),
        _FieldLabel('Notes & Emergency Info'),
        AppTextField(
          label: 'Behavioral notes, emergency instructions, etc.',
          controller: _notesCtrl,
          onChanged: ctrl.setNotes,
          maxLines: 4,
        ),
      ],
    );
  }

  // ── Step 5: Public Profile ────────────────────────────────────────────────

  Widget _step5PublicProfile(
      BuildContext ctx, PetFormState s, PetFormController ctrl) {
    return _WizardCard(
      title: 'Public Pet Profile',
      subtitle: 'Create a social page for your pet',
      children: [
        _InfoBanner(
          'Enable a public profile so others can discover, follow, and like your pet. '
          'Your pet\'s profile works like a public page.',
        ),
        const SizedBox(height: 16),
        _SwitchTile(
          title: 'Enable Public Profile',
          subtitle: 'Others can follow and like your pet',
          value: s.isPublicProfileEnabled,
          onChanged: ctrl.setPublicProfile,
          highlight: true,
        ),
        if (s.isPublicProfileEnabled) ...[
          const SizedBox(height: 20),
          _FieldLabel('Pet Username / Slug'),
          AppTextField(
            label: 'e.g. buddy-the-golden (auto-generated if empty)',
            controller: _slugCtrl,
            onChanged: ctrl.setSlug,
          ),
          const SizedBox(height: 4),
          Text(
            'This will be your pet\'s unique public URL',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Bio / About'),
          AppTextField(
            label: 'A short description about your pet',
            controller: _bioCtrl,
            onChanged: ctrl.setBio,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _FieldLabel('Cover Photo'),
          _CoverPhotoPicker(
            file: s.coverPhotoFile,
            existingUrl: s.coverMediaUrl,
            onPick: () async {
              final x = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 80,
              );
              if (x != null) ctrl.setCoverPhoto(x);
            },
            onRemove: ctrl.removeCoverPhoto,
          ),
        ],
      ],
    );
  }

  // ── Step 6: Review ────────────────────────────────────────────────────────

  Widget _step6Review(
      BuildContext ctx, PetFormState s, PetFormController ctrl) {
    String lookupName(List<Map<String, dynamic>> list, int? id) {
      if (id == null) return '';
      final hit = list.where((e) => e['id'] == id).toList();
      return hit.isEmpty ? '' : (hit.first['name'] ?? '').toString();
    }

    final typeName = lookupName(s.animalTypes, s.animalTypeId);
    final breedName = lookupName(s.breeds, s.breedId);

    return Column(
      children: [
        if (s.photoFile != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(s.photoFile!, height: 180, fit: BoxFit.cover,
                width: double.infinity),
          ),
        const SizedBox(height: 16),
        _WizardCard(
          title: s.name.isEmpty ? 'New Pet' : s.name,
          subtitle: [typeName, breedName].where((s) => s.isNotEmpty).join(' · '),
          children: [
            _ReviewRow('Name', s.name),
            _ReviewRow('Type', typeName),
            _ReviewRow('Breed', s.customBreedText ?? breedName),
            _ReviewRow('Sex', s.sex),
            _ReviewRow('Date of Birth', _dateText(s.dob)),
            if (s.weightKg != null) _ReviewRow('Weight', '${s.weightKg} kg'),
            _ReviewRow('Neutered', s.isNeutered ? 'Yes' : 'No'),
            _ReviewRow('Rescue', s.isRescue ? 'Yes' : 'No'),
            if (s.microchipNumber.isNotEmpty)
              _ReviewRow('Microchip', s.microchipNumber),
            if (s.foodHabits.isNotEmpty)
              _ReviewRow('Food', s.foodHabits),
          ],
        ),
        if (s.isPublicProfileEnabled) ...[
          const SizedBox(height: 12),
          _WizardCard(
            title: 'Public Profile',
            subtitle: 'Visible to everyone',
            children: [
              _ReviewRow('Username', s.slug.isEmpty ? '(auto-generated)' : '@${s.slug}'),
              if (s.bio.isNotEmpty) _ReviewRow('Bio', s.bio),
              _ReviewRow('Visibility', 'Public'),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF9F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.editMode
                      ? 'Ready to save your changes!'
                      : 'Ready to create your pet\'s profile!',
                  style: const TextStyle(
                      color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Common Widgets ─────────────────────────────────────────────────────────────

class _WizardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _WizardCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _WizardProgress extends StatelessWidget {
  final int step;
  final List<String> titles;

  const _WizardProgress({required this.step, required this.titles});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(titles.length, (i) {
              final done = i < step;
              final current = i == step;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFF4C6EF5)
                        : current
                            ? const Color(0xFF4C6EF5).withOpacity(0.4)
                            : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${step + 1} of ${titles.length}: ${titles[step]}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4C6EF5),
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardFooter extends StatelessWidget {
  final PetFormState state;
  final PetFormController ctrl;

  const _WizardFooter({required this.state, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isLast = state.step >= PetFormState.totalSteps - 1;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          if (state.step > 0)
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFF4C6EF5)),
                ),
                onPressed: state.loading ? null : ctrl.back,
                child: const Text('Back',
                    style: TextStyle(color: Color(0xFF4C6EF5))),
              ),
            ),
          if (state.step > 0) const SizedBox(width: 12),
          Expanded(
            flex: state.step > 0 ? 2 : 1,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C6EF5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: state.loading
                  ? null
                  : () {
                      if (!isLast) {
                        ctrl.next();
                      } else {
                        ctrl.submit();
                      }
                    },
              child: state.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isLast
                          ? (state.editMode ? 'Save Changes' : 'Create Pet')
                          : 'Continue',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoPicker({
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF0F2FF),
                border: Border.all(
                    color: const Color(0xFF4C6EF5).withOpacity(0.3), width: 2),
              ),
              child: file == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 32, color: Color(0xFF4C6EF5)),
                        SizedBox(height: 4),
                        Text('Add Photo',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF4C6EF5))),
                      ],
                    )
                  : ClipOval(
                      child: Image.file(file!, fit: BoxFit.cover,
                          width: 110, height: 110),
                    ),
            ),
          ),
          if (file != null)
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverPhotoPicker extends StatelessWidget {
  final File? file;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _CoverPhotoPicker({
    required this.file,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = file != null || existingUrl != null;
    return GestureDetector(
      onTap: onPick,
      child: Stack(
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFF0F2FF),
              border: Border.all(
                  color: const Color(0xFF4C6EF5).withOpacity(0.3)),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: file != null
                        ? Image.file(file!, fit: BoxFit.cover)
                        : Image.network(existingUrl!, fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 36, color: Color(0xFF4C6EF5)),
                      SizedBox(height: 8),
                      Text('Add Cover Photo',
                          style: TextStyle(color: Color(0xFF4C6EF5))),
                    ],
                  ),
          ),
          if (hasImage)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool highlight;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlight && value
            ? const Color(0xFF4C6EF5).withOpacity(0.06)
            : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight && value
              ? const Color(0xFF4C6EF5).withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF4C6EF5),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E))),
          if (required) ...[
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: Color(0xFF4C6EF5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF3A4DCC))),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFB0B8C1)),
            const SizedBox(height: 16),
            const Text(
              'Failed to load animal types',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF666680)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
