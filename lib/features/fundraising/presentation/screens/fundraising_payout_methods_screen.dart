import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fundraising_payout_models.dart';
import '../providers/fundraising_providers.dart';
import '../../data/repositories/fundraising_repository.dart';

import 'fundraising_common_scaffold.dart';

/// Fundraiser payout methods manager (bkash/nagad/bank, etc.)
///
/// Phase C: Withdraw/Payout.
class FundraisingPayoutMethodsScreen extends ConsumerWidget {
  const FundraisingPayoutMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(fundraisingMyPayoutMethodsProvider);
    final catalogAsync = ref.watch(fundraisingPayoutCatalogProvider);

    return FundraisingCommonScaffold(
      title: 'Payout Methods',
      showFilters: false,
      showCreate: false,
      showVerification: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add your payout accounts so you can withdraw raised funds.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final catalog = await catalogAsync.maybeWhen(
                        data: (d) => d,
                        orElse: () => <PayoutCatalogItem>[],
                      );
                      if (catalog.isEmpty && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payout catalog not available.')),
                        );
                        return;
                      }
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => _PayoutMethodEditorDialog(
                          catalog: catalog,
                        ),
                      );
                      if (ok == true) {
                        ref.invalidate(fundraisingMyPayoutMethodsProvider);
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: methodsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('No payout methods yet.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final m = items[index];
                      return _PayoutMethodCard(method: m);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutMethodCard extends ConsumerWidget {
  final FundraisingPayoutMethod method;
  const _PayoutMethodCard({required this.method});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(fundraisingRepositoryProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  method.displayName,
                  style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (method.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Default',
                    style: context.appText.labelMedium!.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  try {
                    if (v == 'default') {
                      await repo.updateMyPayoutMethod(id: method.id, isDefault: true);
                      ref.invalidate(fundraisingMyPayoutMethodsProvider);
                    }
                    if (v == 'toggle') {
                      await repo.updateMyPayoutMethod(id: method.id, isActive: !method.isActive);
                      ref.invalidate(fundraisingMyPayoutMethodsProvider);
                    }
                    if (v == 'edit') {
                      final catalog = await ref.read(fundraisingPayoutCatalogProvider.future);
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => _PayoutMethodEditorDialog(
                          catalog: catalog,
                          existing: method,
                        ),
                      );
                      if (ok == true) {
                        ref.invalidate(fundraisingMyPayoutMethodsProvider);
                      }
                    }
                    if (v == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete payout method?'),
                          content: const Text('You can add it again later.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await repo.deleteMyPayoutMethod(id: method.id);
                        ref.invalidate(fundraisingMyPayoutMethodsProvider);
                      }
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
                itemBuilder: (_) => [
                  if (!method.isDefault)
                    const PopupMenuItem(value: 'default', child: Text('Set as default')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(method.isActive ? 'Disable' : 'Enable'),
                  ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            method.summary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                method.isActive ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: method.isActive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(method.isActive ? 'Active' : 'Disabled'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayoutMethodEditorDialog extends ConsumerStatefulWidget {
  final List<PayoutCatalogItem> catalog;
  final FundraisingPayoutMethod? existing;
  const _PayoutMethodEditorDialog({required this.catalog, this.existing});

  @override
  ConsumerState<_PayoutMethodEditorDialog> createState() => _PayoutMethodEditorDialogState();
}

class _PayoutMethodEditorDialogState extends ConsumerState<_PayoutMethodEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _catalogId;
  final _labelCtrl = TextEditingController();
  final _walletCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _acctNumberCtrl = TextEditingController();
  final _acctNameCtrl = TextEditingController();
  bool _isDefault = false;

  PayoutCatalogItem? get _selectedCatalog =>
      widget.catalog.firstWhere((c) => c.id == _catalogId, orElse: () => widget.catalog.first);

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _catalogId = ex?.catalogId ?? (widget.catalog.isNotEmpty ? widget.catalog.first.id : 0);
    _labelCtrl.text = ex?.label ?? '';
    _isDefault = ex?.isDefault ?? false;

    final d = ex?.detailsJson ?? const <String, dynamic>{};
    _walletCtrl.text = (d['walletNumber'] ?? d['number'] ?? '').toString();
    _bankNameCtrl.text = (d['bankName'] ?? '').toString();
    _acctNumberCtrl.text = (d['accountNumber'] ?? '').toString();
    _acctNameCtrl.text = (d['accountName'] ?? '').toString();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _walletCtrl.dispose();
    _bankNameCtrl.dispose();
    _acctNumberCtrl.dispose();
    _acctNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final c = _selectedCatalog;
    final type = (c?.type ?? '').toUpperCase();

    return AlertDialog(
      title: Text(isEdit ? 'Edit payout method' : 'Add payout method'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _catalogId == 0 && widget.catalog.isNotEmpty ? widget.catalog.first.id : _catalogId,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: widget.catalog
                      .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _catalogId = v;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label (optional)',
                    hintText: 'e.g., Personal, Office, Rescue team',
                  ),
                ),
                const SizedBox(height: 12),
                if (type == 'MFS')
                  TextFormField(
                    controller: _walletCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Wallet number',
                      hintText: '01XXXXXXXXX',
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return 'Wallet number is required';
                      return null;
                    },
                  ),
                if (type == 'BANK') ...[
                  TextFormField(
                    controller: _bankNameCtrl,
                    decoration: const InputDecoration(labelText: 'Bank name'),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return 'Bank name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _acctNumberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Account number'),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return 'Account number is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _acctNameCtrl,
                    decoration: const InputDecoration(labelText: 'Account holder name (optional)'),
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  title: const Text('Set as default'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            try {
              final repo = ref.read(fundraisingRepositoryProvider);
              final details = <String, dynamic>{};
              if (type == 'MFS') {
                details['walletNumber'] = _walletCtrl.text.trim();
              } else if (type == 'BANK') {
                details['bankName'] = _bankNameCtrl.text.trim();
                details['accountNumber'] = _acctNumberCtrl.text.trim();
                if (_acctNameCtrl.text.trim().isNotEmpty) {
                  details['accountName'] = _acctNameCtrl.text.trim();
                }
              }

              if (isEdit) {
                await repo.updateMyPayoutMethod(
                  id: widget.existing!.id,
                  label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
                  detailsJson: details,
                  isDefault: _isDefault,
                );
              } else {
                await repo.createMyPayoutMethod(
                  catalogId: _catalogId,
                  label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
                  detailsJson: details,
                  isDefault: _isDefault,
                );
              }

              if (!context.mounted) return;
              Navigator.pop(context, true);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
