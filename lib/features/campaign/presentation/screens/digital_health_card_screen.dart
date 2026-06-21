import 'package:flutter/material.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:bpa_app/features/pets/data/pet_service.dart';
import 'package:bpa_app/features/pets/data/models/pet_profile_model.dart';
import 'package:bpa_app/features/pets/presentation/providers/pet_providers.dart';

import '../providers/campaign_providers.dart';
import '../utils/campaign_health_utils.dart';
import '../widgets/digital_vaccination_card_widget.dart';
import 'certificate_viewer_screen.dart';
import 'certificate_wallet_screen.dart';
import 'qr_verification_screen.dart';
import 'vaccination_timeline_screen.dart';
import 'vaccination_reminders_screen.dart';

/// Digital health card tied to an existing pet profile.
class DigitalHealthCardScreen extends ConsumerStatefulWidget {
  /// When null, user picks a pet first.
  final int? petId;

  const DigitalHealthCardScreen({super.key, this.petId});

  @override
  ConsumerState<DigitalHealthCardScreen> createState() => _DigitalHealthCardScreenState();
}

class _DigitalHealthCardScreenState extends ConsumerState<DigitalHealthCardScreen> {
  int? _selectedPetId;
  PetProfileModel? _profile;
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _selectedPetId = widget.petId;
    if (_selectedPetId != null) {
      _loadProfile(_selectedPetId!);
    }
  }

  Future<void> _loadProfile(int petId) async {
    setState(() => _loadingProfile = true);
    try {
      final p = await PetService().getPetProfile(petId);
      if (mounted) setState(() => _profile = p);
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedPetId == null) {
      return _PetPicker(
        onSelected: (id) {
          setState(() => _selectedPetId = id);
          _loadProfile(id);
        },
      );
    }

    final petId = _selectedPetId!;
    final recordsAsync = ref.watch(
      petVaccinationRecordsProvider(
        PetHealthFilter(petId: petId, petName: _profile?.name),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(_profile?.name ?? 'Digital Health Card'),
        backgroundColor: context.colorScheme.primary,
        foregroundColor: context.colorScheme.onPrimary,
        actions: [
          if (widget.petId == null)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Change pet',
              onPressed: () => setState(() {
                _selectedPetId = null;
                _profile = null;
              }),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
            petVaccinationRecordsProvider(PetHealthFilter(petId: petId, petName: _profile?.name)),
          );
          ref.invalidate(vaccinationRecordsProvider);
          await _loadProfile(petId);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loadingProfile)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (_profile != null)
              _ProfileSummary(profile: _profile!),
            const SizedBox(height: 16),
            _QuickActions(
              onWallet: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CertificateWalletScreen()),
              ),
              onTimeline: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VaccinationTimelineScreen(petId: petId, petName: _profile?.name),
                ),
              ),
              onReminders: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VaccinationRemindersScreen()),
              ),
              onVerify: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrVerificationScreen()),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Vaccination cards',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            recordsAsync.when(
              data: (records) {
                final withCerts = recordsWithCertificates(records);
                if (withCerts.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _profile?.vaccinated == true
                            ? 'Vaccination on file — campaign certificate will appear after BPA clinic visit or import.'
                            : 'No digital vaccination cards for ${_profile?.name ?? "this pet"} yet. Complete a BPA campaign vaccination or import records.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return Column(
                  children: withCerts
                      .map(
                        (r) => DigitalVaccinationCardWidget(
                          record: r,
                          photoUrl: _profile?.photoUrl,
                          onTap: r.certificateToken == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CertificateViewerScreen(token: r.certificateToken!),
                                    ),
                                  ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final PetProfileModel profile;

  const _ProfileSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    final due = profile.nextDueDate != null
        ? DateFormat('d MMM yyyy').format(profile.nextDueDate!)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage:
                  profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
              child: profile.photoUrl == null
                  ? Text(profile.name.isNotEmpty ? profile.name[0] : '?',
                      style: context.appText.headlineLarge!.copyWith(fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: context.appText.titleMedium!.copyWith(fontWeight: FontWeight.w800)),
                  if (profile.breed != null) Text(profile.breed!, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(profile.vaccinated ? 'Vaccinated' : 'Due / pending'),
                        backgroundColor:
                            profile.vaccinated ? Colors.green.shade50 : Colors.orange.shade50,
                        labelStyle: context.appText.labelMedium!.copyWith(
                          color: profile.vaccinated ? Colors.green.shade800 : Colors.orange.shade900,
                        ),
                      ),
                      if (due != null)
                        Chip(
                          label: Text('Next due $due'),
                          labelStyle: context.appText.bodySmall,
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
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onWallet;
  final VoidCallback onTimeline;
  final VoidCallback onReminders;
  final VoidCallback onVerify;

  const _QuickActions({
    required this.onWallet,
    required this.onTimeline,
    required this.onReminders,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.account_balance_wallet_outlined, size: 18),
          label: const Text('Wallet'),
          onPressed: onWallet,
        ),
        ActionChip(
          avatar: const Icon(Icons.timeline_rounded, size: 18),
          label: const Text('Timeline'),
          onPressed: onTimeline,
        ),
        ActionChip(
          avatar: const Icon(Icons.notifications_outlined, size: 18),
          label: const Text('Reminders'),
          onPressed: onReminders,
        ),
        ActionChip(
          avatar: const Icon(Icons.qr_code_scanner_rounded, size: 18),
          label: const Text('Verify QR'),
          onPressed: onVerify,
        ),
      ],
    );
  }
}

class _PetPicker extends ConsumerWidget {
  final ValueChanged<int> onSelected;

  const _PetPicker({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Health Card'),
        backgroundColor: context.colorScheme.primary,
        foregroundColor: context.colorScheme.onPrimary,
      ),
      body: FutureBuilder(
        future: ref.read(getPetsUsecaseProvider).call(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          final pets = snap.data ?? [];
          if (pets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Add a pet profile first to view a digital health card.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pets.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final pet = pets[i];
              final id = pet.id;
              if (id == null) return const SizedBox.shrink();
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.white,
                leading: const CircleAvatar(child: Icon(Icons.pets)),
                title: Text(pet.name),
                subtitle: Text(pet.breedName ?? 'Pet'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelected(id),
              );
            },
          );
        },
      ),
    );
  }
}
