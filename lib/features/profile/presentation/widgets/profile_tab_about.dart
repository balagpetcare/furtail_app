import 'package:flutter/material.dart';
import '../../data/models/user_profile_model.dart';

/// About tab for own profile.
///
/// Shows filled public fields with friendly card layout.
/// Empty fields are shown as tappable "Add …" prompts — never as "Not set".
/// Sensitive fields (gender, religion, birthdate, marital status) are grouped
/// in a clearly-labelled Private section, hidden when all are empty.
class ProfileTabAbout extends StatelessWidget {
  final UserProfileModel profile;
  final VoidCallback? onSeeMore;

  const ProfileTabAbout({
    super.key,
    required this.profile,
    this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bio      = (profile.bio ?? '').trim();
    final livesIn  = (profile.placeLive ?? '').trim();
    final from     = (profile.from ?? '').trim();
    final profType = (profile.profileType ?? '').trim();
    final work     = (profile.workStatus ?? '').trim();
    final edu      = (profile.education ?? '').trim();

    final gender   = (profile.gender ?? '').trim();
    final religion = (profile.religiousStatus ?? '').trim();
    final marital  = (profile.maritalStatus ?? '').trim();
    final bday     = profile.birthdate;

    final hasIntro = livesIn.isNotEmpty || from.isNotEmpty ||
        profType.isNotEmpty || work.isNotEmpty || edu.isNotEmpty;
    final hasPrivate = gender.isNotEmpty || religion.isNotEmpty ||
        marital.isNotEmpty || bday != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Bio ──────────────────────────────────────────────────────────────
        _secTitle('Bio'),
        const SizedBox(height: 8),
        if (bio.isNotEmpty)
          _card(
            cs,
            child: Text(bio, style: const TextStyle(fontSize: 14, height: 1.55)),
          )
        else
          _addPrompt(context, cs, 'Add a bio to tell people about yourself',
              Icons.edit_note_rounded, onSeeMore),

        const SizedBox(height: 20),

        // ── Intro ─────────────────────────────────────────────────────────────
        _secTitle('Intro'),
        const SizedBox(height: 8),
        if (hasIntro)
          _card(
            cs,
            child: Column(
              children: [
                if (profType.isNotEmpty)
                  _iconRow(Icons.person_outline, 'Profile type: $profType'),
                if (livesIn.isNotEmpty)
                  _iconRow(Icons.home_outlined, 'Lives in $livesIn'),
                if (from.isNotEmpty)
                  _iconRow(Icons.location_on_outlined, 'From $from'),
                if (work.isNotEmpty) _iconRow(Icons.work_outline, work),
                if (edu.isNotEmpty)
                  _iconRow(Icons.school_outlined, 'Studied at $edu'),
              ],
            ),
          )
        else
          _addPrompt(context, cs, 'Add your location, work, and education',
              Icons.add_location_alt_outlined, onSeeMore),

        // ── Private personal info (only when at least one field is set) ──────
        if (hasPrivate) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              _secTitle('Personal Info'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _card(
            cs,
            child: Column(
              children: [
                if (gender.isNotEmpty)
                  _iconRow(Icons.wc_outlined, gender),
                if (religion.isNotEmpty)
                  _iconRow(Icons.brightness_low_outlined, religion),
                if (marital.isNotEmpty)
                  _iconRow(Icons.favorite_border_rounded, marital),
                if (bday != null)
                  _iconRow(Icons.cake_outlined, _fmtDate(bday)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ── Edit button ───────────────────────────────────────────────────────
        if (onSeeMore != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSeeMore,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit About Details'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

        SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Widget _secTitle(String t) => Text(
        t,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      );

  static Widget _card(ColorScheme cs, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }

  static Widget _addPrompt(
    BuildContext context,
    ColorScheme cs,
    String hint,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: TextStyle(
                  color: cs.primary,
                  fontStyle: FontStyle.italic,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _iconRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}
