import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/campaign_providers.dart';

class VaccinationRemindersScreen extends ConsumerWidget {
  const VaccinationRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(vaccinationRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccination Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(vaccinationRemindersProvider.notifier).refreshFromRecords(),
          ),
        ],
      ),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No booster due dates found yet. Reminders appear after vaccinations with next due dates.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reminders.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = reminders[i];
              final due = DateFormat('d MMM yyyy').format(r.dueDate);
              final remindOn = r.dueDate.subtract(Duration(days: r.daysBefore));
              return Card(
                child: SwitchListTile(
                  title: Text('${r.petName} · ${r.vaccineType}'),
                  subtitle: Text(
                    'Due $due · Remind on ${DateFormat('d MMM yyyy').format(remindOn)}',
                  ),
                  value: r.enabled,
                  onChanged: (v) =>
                      ref.read(vaccinationRemindersProvider.notifier).toggle(r.id, v),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}
