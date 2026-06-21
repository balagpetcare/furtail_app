import 'dart:ui';

import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';

import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/campaign/presentation/screens/digital_health_card_screen.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';

import '../../data/pet_service.dart';
import '../../data/models/pet_profile_model.dart';
import 'pet_edit_overview_screen.dart';

class PetProfileScreen extends StatefulWidget {
  final int petId;
  const PetProfileScreen({super.key, required this.petId});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  late Future<PetProfileModel> _future;
  final _service = PetService();

  @override
  void initState() {
    super.initState();
    _future = _service.getPetProfile(widget.petId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.getPetProfile(widget.petId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Pet Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => ShareService.share(context, type: 'pet', id: widget.petId),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') {
                ReportBottomSheet.show(
                  context,
                  targetType: ReportTargetType.pet,
                  targetId: widget.petId,
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<PetProfileModel>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Failed to load pet profile\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final pet = snap.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderHero(pet: pet),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _InfoGrid(pet: pet),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionTitle(title: 'Health Status', icon: Icons.shield_outlined),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _HealthRow(pet: pet),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _GradientButton(
                        icon: Icons.qr_code_rounded,
                        label: 'Digital Health Card',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DigitalHealthCardScreen(petId: widget.petId),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionTitle(title: 'My Family', icon: Icons.pets_outlined),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _FamilyRow(family: pet.family),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionTitle(title: 'Activity & Points', icon: Icons.directions_run_rounded),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _PointsCard(points: pet.pawPoints),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _QuickActions(
                        onMedical: () => _toast(context, 'Next: Medical History'),
                        onDiet: () => _toast(context, 'Next: Diet Chart'),
                        onGallery: () => _toast(context, 'Next: Gallery'),
                        onEdit: () async {
                          final ok = await Navigator.push(
                            context,
                            // ✅ New edit flow: overview page -> per-field edit pages
                            MaterialPageRoute(builder: (_) => PetEditOverviewScreen(petId: widget.petId)),
                          );
                          if (ok == true) {
                            await _refresh();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _HeaderHero extends StatelessWidget {
  final PetProfileModel pet;
  const _HeaderHero({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black12,
              image: pet.photoUrl == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(pet.photoUrl!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: pet.photoUrl == null
                ? const Center(
                    child: Icon(Icons.pets, size: 72, color: Colors.white70),
                  )
                : null,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.40),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _RoundIconButton(
            icon: Icons.share_outlined,
            onTap: () {
              ShareService.share(context, type: 'pet', id: pet.id);
            },
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Row(
            children: [
              Text(
                pet.name,
                style: context.appText.displayLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.0),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.verified_rounded, color: Color(0xFF2D7FF9), size: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: Icon(icon, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final PetProfileModel pet;
  const _InfoGrid({required this.pet});

  @override
  Widget build(BuildContext context) {
    String ageText;
    if (pet.ageYears == null) {
      ageText = '--';
    } else {
      ageText = '${pet.ageYears} Yrs';
    }
    final weightText = pet.weightKg == null ? '--' : '${pet.weightKg!.toStringAsFixed(0)} Kg';
    final genderText = (pet.gender ?? 'UNKNOWN').toLowerCase();

    return _GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _InfoItem(icon: Icons.schedule, label: 'Age', value: ageText)),
              _DividerV(),
              Expanded(child: _InfoItem(icon: Icons.pets, label: 'Breed', value: pet.breed ?? '--')),
            ],
          ),
          const _DividerH(),
          Row(
            children: [
              Expanded(child: _InfoItem(icon: Icons.monitor_weight_outlined, label: 'Weight', value: weightText)),
              _DividerV(),
              Expanded(child: _InfoItem(icon: genderText == 'female' ? Icons.female : Icons.male, label: 'Gender', value: (pet.gender ?? '--').toString().toLowerCase().capitalize())),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.appText.bodyMedium!.copyWith(color: Colors.black54)),
                const SizedBox(height: 2),
                Text(value, style: context.appText.titleMedium!.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final PetProfileModel pet;
  const _HealthRow({required this.pet});

  @override
  Widget build(BuildContext context) {
    final due = pet.nextDueDate == null
        ? '--'
        : '${pet.nextDueDate!.day.toString().padLeft(2, '0')} ${_monthShort(pet.nextDueDate!.month)}';

    return Row(
      children: [
        Expanded(
          child: _Pill(
            leading: const _PillIcon(bg: Color(0xFFDFF6E7), icon: Icons.verified_rounded, iconColor: Color(0xFF1EAD5A)),
            title: 'Fully',
            value: pet.vaccinated ? 'Vaccinated' : 'Not Vaccinated',
            tint: const Color(0xFFEAF9F0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Pill(
            leading: const _PillIcon(bg: Color(0xFFFFE7D6), icon: Icons.calendar_month_rounded, iconColor: Color(0xFFF0852B)),
            title: 'Next Due:',
            value: due,
            tint: const Color(0xFFFFF1E8),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget leading;
  final String title;
  final String value;
  final Color tint;
  const _Pill({required this.leading, required this.title, required this.value, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.appText.bodySmall!.copyWith(color: Colors.black54)),
                const SizedBox(height: 2),
                Text(value, style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final Color iconColor;
  const _PillIcon({required this.bg, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: iconColor),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(colors: [Color(0xFF2D7FF9), Color(0xFFF0852B)]),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: context.appText.bodyLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _FamilyRow extends StatelessWidget {
  final List<PetFamilyMemberModel> family;
  const _FamilyRow({required this.family});

  @override
  Widget build(BuildContext context) {
    if (family.isEmpty) {
      return _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.black45),
              SizedBox(width: 10),
              Expanded(child: Text('No family members added yet.')),
            ],
          ),
        ),
      );
    }

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: family.map((m) {
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.black12,
                      backgroundImage: m.avatarUrl == null ? null : NetworkImage(m.avatarUrl!),
                      child: m.avatarUrl == null ? const Icon(Icons.person, color: Colors.white70) : null,
                    ),
                    const SizedBox(height: 6),
                    Text(_relationLabel(m.relation), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _relationLabel(String r) {
    switch (r.toUpperCase()) {
      case 'DAD':
        return 'Dad';
      case 'MOM':
        return 'Mom';
      case 'BROTHER':
        return 'Brother';
      case 'SISTER':
        return 'Sister';
      case 'OWNER':
        return 'Owner';
      default:
        return 'Family';
    }
  }
}

class _PointsCard extends StatelessWidget {
  final int points;
  const _PointsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final progress = (points % 2000) / 2000.0;
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7D6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.pets_rounded, color: Color(0xFFF0852B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${points.toString()} Paw Points',
                    style: context.appText.titleMedium!.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.star_rounded, color: Color(0xFFF0B429)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.black12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(''),
                Text('Next level', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onMedical;
  final VoidCallback onDiet;
  final VoidCallback onGallery;
  final VoidCallback onEdit;
  const _QuickActions({
    required this.onMedical,
    required this.onDiet,
    required this.onGallery,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Action(icon: Icons.receipt_long_rounded, label: 'Medical\nHistory', onTap: onMedical),
            _Action(icon: Icons.restaurant_menu_rounded, label: 'Diet\nChart', onTap: onDiet),
            _Action(icon: Icons.photo_library_rounded, label: 'Gallery', onTap: onGallery),
            _Action(icon: Icons.edit_rounded, label: 'Edit\nProfile', onTap: onEdit),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF2D7FF9)),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: context.appText.labelMedium!.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.black87),
        const SizedBox(width: 10),
        Text(title, style: context.appText.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.7)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DividerH extends StatelessWidget {
  const _DividerH();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.black12);
  }
}

class _DividerV extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 86, color: Colors.black12);
  }
}

String _monthShort(int m) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return months[(m - 1).clamp(0, 11)];
}

extension _CapExt on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
