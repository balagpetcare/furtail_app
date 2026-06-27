import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_form_payload.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/my_adoption_applications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdoptionApplyScreen extends StatefulWidget {
  final AdoptionPetUiModel pet;
  final AdoptionRepository repository;

  const AdoptionApplyScreen({
    super.key,
    required this.pet,
    required this.repository,
  });

  @override
  State<AdoptionApplyScreen> createState() => _AdoptionApplyScreenState();
}

class _AdoptionApplyScreenState extends State<AdoptionApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _housingTypeController = TextEditingController();
  final _experienceController = TextEditingController();
  final _currentPetsController = TextEditingController();
  final _incomeRangeController = TextEditingController();
  final _reasonController = TextEditingController();
  final _ownerConditionsController = TextEditingController();

  bool _familyApproval = false;
  bool _canProvideVetCare = false;
  bool _acceptsTerms = false;
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;
  bool _isSubmitting = false;
  bool _isOwnListing = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _housingTypeController.dispose();
    _experienceController.dispose();
    _currentPetsController.dispose();
    _incomeRangeController.dispose();
    _reasonController.dispose();
    _ownerConditionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply to Adopt')),
      body: _isCheckingAuth
          ? const Center(child: CircularProgressIndicator())
          : !_isLoggedIn
          ? const _ApplyStateCard(
              title: 'Login required',
              message: 'Sign in before applying to adopt a pet.',
              icon: Icons.lock_outline_rounded,
            )
          : _isOwnListing
          ? const _ApplyStateCard(
              title: 'Application not allowed',
              message: 'You cannot apply to your own listing.',
              icon: Icons.block_rounded,
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _SectionCard(
                    title: 'Your location',
                    child: _buildTextField(
                      controller: _locationController,
                      label: 'City, district, or area',
                      validator: _requiredField,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionCard(
                    title: 'Home and family information',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _housingTypeController,
                          label: 'Housing type',
                          hintText: 'Apartment, family house, rented home',
                          validator: _requiredField,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SwitchListTile(
                          value: _familyApproval,
                          onChanged: (value) =>
                              setState(() => _familyApproval = value),
                          title: const Text('Family approval confirmed'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionCard(
                    title: 'Previous pet experience',
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _experienceController,
                          label: 'Previous pet experience',
                          maxLines: 4,
                          validator: _requiredField,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _currentPetsController,
                          label: 'Current pets note',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionCard(
                    title: 'Financial readiness',
                    child: _buildTextField(
                      controller: _incomeRangeController,
                      label: 'Income range (optional)',
                      hintText: 'Example: BDT 30k-50k',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionCard(
                    title: 'Vet care commitment',
                    child: SwitchListTile(
                      value: _canProvideVetCare,
                      onChanged: (value) =>
                          setState(() => _canProvideVetCare = value),
                      title: const Text('I can provide routine and emergency vet care'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionCard(
                    title: 'Why do you want to adopt this pet?',
                    child: _buildTextField(
                      controller: _reasonController,
                      label: 'Reason for adoption',
                      maxLines: 5,
                      validator: _requiredField,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionCard(
                    title: 'Owner conditions and agreements',
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _ownerConditionsController,
                          label: 'Answers or notes for owner conditions',
                          maxLines: 4,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SwitchListTile(
                          value: _acceptsTerms,
                          onChanged: (value) =>
                              setState(() => _acceptsTerms = value),
                          title: const Text(
                            'I agree to owner conditions and no resale / no abandonment',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Application'),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();
    final userId = prefs.getInt('userId');
    if (!mounted) return;
    setState(() {
      _isLoggedIn = token.isNotEmpty;
      _isOwnListing = userId != null &&
          widget.pet.ownerUserId != null &&
          userId == widget.pet.ownerUserId;
      _isCheckingAuth = false;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptsTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must accept the owner conditions before submitting.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.applyToAdopt(
        widget.pet.id,
        AdoptionApplicationFormPayload(
          applicantLocationText: _locationController.text,
          housingType: _housingTypeController.text,
          familyApproval: _familyApproval,
          previousPetExperience: _experienceController.text,
          currentPetsNote: _currentPetsController.text,
          incomeRange: _incomeRangeController.text,
          canProvideVetCare: _canProvideVetCare,
          adoptionReason: _reasonController.text,
          ownerConditionAnswers: _ownerConditionsController.text,
          acceptsTerms: _acceptsTerms,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adoption application submitted successfully.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MyAdoptionApplicationsScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    if (raw.contains('already applied')) {
      return 'You already applied to this adoption listing.';
    }
    if (raw.contains('own listing')) {
      return 'You cannot apply to your own listing.';
    }
    if (raw.contains('Token not found')) {
      return 'Please sign in again before applying.';
    }
    return raw.isEmpty
        ? 'Could not submit the adoption application right now.'
        : raw;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.menuTitle(
              context,
            ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ApplyStateCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _ApplyStateCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: cs.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: AppTypography.sectionTitle(
                  context,
                ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyRegular(
                  context,
                ).copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
