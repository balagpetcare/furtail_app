import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_listing_form_payload.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/my_adoption_listings_screen.dart';
import 'package:furtail_app/features/legacy/data/models/country_model.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateAdoptionListingScreen extends StatefulWidget {
  const CreateAdoptionListingScreen({super.key});

  @override
  State<CreateAdoptionListingScreen> createState() =>
      _CreateAdoptionListingScreenState();
}

class _CreateAdoptionListingScreenState
    extends State<CreateAdoptionListingScreen> {
  static const _speciesOptions = ['CAT', 'DOG', 'BIRD', 'RABBIT', 'OTHER'];
  static const _genderOptions = ['UNKNOWN', 'MALE', 'FEMALE'];
  static const _serviceAreaTypes = [
    'SAME_AREA',
    'SAME_CITY',
    'SAME_DISTRICT',
    'SAME_DIVISION',
    'ANYWHERE_COUNTRY',
    'CUSTOM_AREAS',
    'RADIUS_BASED',
    'INTERNATIONAL',
  ];

  final _formKey = GlobalKey<FormState>();
  late final AdoptionRepository _repository;

  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _sizeController = TextEditingController();
  final _colorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reasonController = TextEditingController();
  final _healthController = TextEditingController();
  final _stateIdController = TextEditingController();
  final _cityIdController = TextEditingController();
  final _divisionIdController = TextEditingController();
  final _districtIdController = TextEditingController();
  final _upazilaIdController = TextEditingController();
  final _areaIdController = TextEditingController();
  final _customAreasController = TextEditingController();
  final _serviceAreaNotesController = TextEditingController();
  final _minIncomeController = TextEditingController();
  final _maxIncomeController = TextEditingController();
  final _conditionNoteController = TextEditingController();

  String _species = 'CAT';
  String _gender = 'UNKNOWN';
  String _serviceAreaType = 'ANYWHERE_COUNTRY';
  bool _vaccinated = false;
  bool _dewormed = false;
  bool _neutered = false;
  bool _microchipped = false;
  bool _allowInternationalAdoption = false;
  bool _previousPetExperienceRequired = false;
  bool _familyApprovalRequired = false;
  bool _canProvideVetCare = false;
  bool _noResaleAgreement = true;
  bool _followUpAgreement = false;
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;
  bool _isSubmitting = false;
  int _currentStep = 0;
  Country? _bangladeshCountry;
  String? _countryError;

  @override
  void initState() {
    super.initState();
    _repository = AdoptionRepository(AdoptionRemoteDs(ApiClient()));
    _checkAuth();
    _resolveBangladeshCountry();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _sizeController.dispose();
    _colorController.dispose();
    _descriptionController.dispose();
    _reasonController.dispose();
    _healthController.dispose();
    _stateIdController.dispose();
    _cityIdController.dispose();
    _divisionIdController.dispose();
    _districtIdController.dispose();
    _upazilaIdController.dispose();
    _areaIdController.dispose();
    _customAreasController.dispose();
    _serviceAreaNotesController.dispose();
    _minIncomeController.dispose();
    _maxIncomeController.dispose();
    _conditionNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Adoption Listing')),
      body: _isCheckingAuth
          ? const Center(child: CircularProgressIndicator())
          : !_isLoggedIn
          ? _LoginRequiredState(onBack: () => Navigator.of(context).maybePop())
          : Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepTapped: (value) => setState(() => _currentStep = value),
                onStepContinue: _currentStep == 4
                    ? null
                    : () => setState(() => _currentStep += 1),
                onStepCancel: _currentStep == 0
                    ? null
                    : () => setState(() => _currentStep -= 1),
                controlsBuilder: (context, details) {
                  final isLast = _currentStep == 4;
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (!isLast)
                          FilledButton(
                            onPressed: details.onStepContinue,
                            child: const Text('Next'),
                          ),
                        if (_currentStep > 0)
                          OutlinedButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Back'),
                          ),
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Pet Basic Info'),
                    isActive: _currentStep >= 0,
                    content: _SectionCard(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Pet name',
                          validator: _requiredField,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: _species,
                          decoration: const InputDecoration(
                            labelText: 'Species',
                          ),
                          items: _speciesOptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _species = value ?? _species),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _breedController,
                          label: 'Breed',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _ageController,
                          label: 'Age text',
                          hintText: 'Example: 2 years',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                          ),
                          items: _genderOptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _gender = value ?? _gender),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _sizeController,
                          label: 'Size',
                          hintText: 'Small, Medium, Large',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _colorController,
                          label: 'Color',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                color: cs.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Photo and video upload will be connected in a later step. This form keeps media as a safe placeholder for now.',
                                  style: AppTypography.caption(context)
                                      .copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Story and Reason'),
                    isActive: _currentStep >= 1,
                    content: _SectionCard(
                      children: [
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description / story',
                          maxLines: 5,
                          validator: _requiredField,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _reasonController,
                          label: 'Adoption reason',
                          maxLines: 4,
                          validator: _requiredField,
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Health Info'),
                    isActive: _currentStep >= 2,
                    content: _SectionCard(
                      children: [
                        SwitchListTile(
                          value: _vaccinated,
                          onChanged: (value) =>
                              setState(() => _vaccinated = value),
                          title: const Text('Vaccinated'),
                        ),
                        SwitchListTile(
                          value: _dewormed,
                          onChanged: (value) =>
                              setState(() => _dewormed = value),
                          title: const Text('Dewormed'),
                        ),
                        SwitchListTile(
                          value: _neutered,
                          onChanged: (value) =>
                              setState(() => _neutered = value),
                          title: const Text('Neutered / spayed'),
                        ),
                        SwitchListTile(
                          value: _microchipped,
                          onChanged: (value) =>
                              setState(() => _microchipped = value),
                          title: const Text('Microchipped'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _healthController,
                          label: 'Current illness / treatment note',
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Location and Service Area'),
                    isActive: _currentStep >= 3,
                    content: _SectionCard(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Country',
                                style: AppTypography.menuTitle(
                                  context,
                                ).copyWith(color: cs.onSurface),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _bangladeshCountry == null
                                    ? 'Bangladesh'
                                    : 'Bangladesh (ID: ${_bangladeshCountry!.id})',
                                style: AppTypography.bodyRegular(
                                  context,
                                ).copyWith(color: cs.onSurfaceVariant),
                              ),
                              if (_countryError != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _countryError!,
                                  style: AppTypography.caption(
                                    context,
                                  ).copyWith(color: cs.error),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                OutlinedButton.icon(
                                  onPressed: _resolveBangladeshCountry,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry country lookup'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _divisionIdController,
                          label: 'Division / state ID',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _districtIdController,
                          label: 'District / city ID',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _upazilaIdController,
                          label: 'Upazila / sub-district ID',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _areaIdController,
                          label: 'Area ID',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _stateIdController,
                          label: 'Global state ID',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _cityIdController,
                          label: 'Global city ID',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: _serviceAreaType,
                          decoration: const InputDecoration(
                            labelText: 'Service area type',
                          ),
                          items: _serviceAreaTypes
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => _serviceAreaType = value ?? _serviceAreaType,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SwitchListTile(
                          value: _allowInternationalAdoption,
                          onChanged: (value) => setState(
                            () => _allowInternationalAdoption = value,
                          ),
                          title: const Text('Allow international adoption'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _customAreasController,
                          label: 'Custom service areas',
                          hintText: 'Comma separated if needed',
                          maxLines: 2,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _serviceAreaNotesController,
                          label: 'Service area note',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Adopter Conditions'),
                    isActive: _currentStep >= 4,
                    content: _SectionCard(
                      children: [
                        SwitchListTile(
                          value: _previousPetExperienceRequired,
                          onChanged: (value) => setState(
                            () => _previousPetExperienceRequired = value,
                          ),
                          title: const Text('Previous pet experience required'),
                        ),
                        SwitchListTile(
                          value: _familyApprovalRequired,
                          onChanged: (value) => setState(
                            () => _familyApprovalRequired = value,
                          ),
                          title: const Text('Family approval required'),
                        ),
                        SwitchListTile(
                          value: _canProvideVetCare,
                          onChanged: (value) => setState(
                            () => _canProvideVetCare = value,
                          ),
                          title: const Text('Must be able to provide vet care'),
                        ),
                        SwitchListTile(
                          value: _noResaleAgreement,
                          onChanged: (value) =>
                              setState(() => _noResaleAgreement = value),
                          title: const Text(
                            'No resale / no abandonment agreement',
                          ),
                        ),
                        SwitchListTile(
                          value: _followUpAgreement,
                          onChanged: (value) =>
                              setState(() => _followUpAgreement = value),
                          title: const Text('Post-adoption follow-up agreement'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _minIncomeController,
                                label: 'Income range min',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _buildTextField(
                                controller: _maxIncomeController,
                                label: 'Income range max',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _conditionNoteController,
                          label: 'Custom adopter condition note',
                          maxLines: 4,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmitting || _bangladeshCountry == null
                                    ? null
                                    : () => _submit(submitNow: false),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save Draft'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: FilledButton(
                                onPressed: _isSubmitting || _bangladeshCountry == null
                                    ? null
                                    : () => _submit(submitNow: true),
                                child: const Text('Publish Now'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = token.isNotEmpty;
      _isCheckingAuth = false;
    });
  }

  Future<void> _resolveBangladeshCountry() async {
    try {
      final country = await _repository.fetchBangladeshCountry();
      if (!mounted) return;
      setState(() {
        _bangladeshCountry = country;
        _countryError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _countryError =
            'Could not resolve Bangladesh country ID. Please retry before submitting.';
      });
    }
  }

  Future<void> _submit({required bool submitNow}) async {
    if (!_isLoggedIn || _isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }

    final payload = AdoptionListingFormPayload(
      name: _nameController.text,
      species: _species,
      breed: _breedController.text,
      ageText: _ageController.text,
      gender: _gender,
      sizeText: _sizeController.text,
      colorText: _colorController.text,
      description: _descriptionController.text,
      adoptionReason: _reasonController.text,
      vaccinated: _vaccinated,
      dewormed: _dewormed,
      neutered: _neutered,
      microchipped: _microchipped,
      healthInfo: _healthController.text,
      countryIdText: _bangladeshCountry?.id.toString() ?? '',
      stateIdText: _stateIdController.text,
      cityIdText: _cityIdController.text,
      divisionIdText: _divisionIdController.text,
      districtIdText: _districtIdController.text,
      upazilaIdText: _upazilaIdController.text,
      areaIdText: _areaIdController.text,
      serviceAreaType: _serviceAreaType,
      allowInternationalAdoption: _allowInternationalAdoption,
      customServiceAreasText: _customAreasController.text,
      serviceAreaNotes: _serviceAreaNotesController.text,
      previousPetExperienceRequired: _previousPetExperienceRequired,
      familyApprovalRequired: _familyApprovalRequired,
      canProvideVetCare: _canProvideVetCare,
      noResaleAgreement: _noResaleAgreement,
      followUpAgreement: _followUpAgreement,
      minimumIncomeRange: _minIncomeController.text,
      maximumIncomeRange: _maxIncomeController.text,
      adopterConditionNote: _conditionNoteController.text,
    );

    setState(() => _isSubmitting = true);
    try {
      await _repository.createAdoptionListing(
        payload,
        submitNow: submitNow,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submitNow
                ? 'Your adoption listing is now public.'
                : 'Adoption draft saved successfully.',
          ),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MyAdoptionListingsScreen(),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _requiredField(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('Token not found')) {
      return 'Please sign in again before creating an adoption listing.';
    }
    if (raw.contains('Validation error')) {
      return 'The adoption form contains invalid data. Please review the highlighted fields.';
    }
    return raw.isEmpty
        ? 'Could not save the adoption listing right now.'
        : raw;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _LoginRequiredState extends StatelessWidget {
  final VoidCallback onBack;

  const _LoginRequiredState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 38, color: cs.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Login required',
                style: AppTypography.sectionTitle(
                  context,
                ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sign in before creating or submitting an adoption listing.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyRegular(
                  context,
                ).copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: onBack,
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
