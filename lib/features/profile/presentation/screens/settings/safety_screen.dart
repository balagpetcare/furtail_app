import 'package:flutter/material.dart';

import '../../../data/safety_service.dart';
import '../../widgets/settings_scaffold.dart';

enum _SafetyKind {
  blocked('Blocked', 'blocked'),
  muted('Muted', 'muted'),
  restricted('Restricted', 'restricted');

  const _SafetyKind(this.tabLabel, this.noun);

  /// Text shown on the TabBar for this kind.
  final String tabLabel;

  /// Lowercase noun used in empty/confirmation copy ("No $noun users.").
  final String noun;
}

/// Manage blocked, muted, and restricted users.
///
/// Tabs and pages are both generated from the single [_SafetyKind.values]
/// list in the same order, so a tab can never end up paired with another
/// tab's page — there is only one place that defines the order.
class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key, this.safetyService});
  final SafetyService? safetyService;

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> with SingleTickerProviderStateMixin {
  late final SafetyService _svc = widget.safetyService ?? SafetyService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _SafetyKind.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SettingsScaffold(
      title: 'Safety',
      scrollable: false,
      bottom: TabBar(
        controller: _tabController,
        // Explicit colors, measured (see test/core/theme/contrast_test.dart):
        // selected onPrimary/primary = 6.35:1, unselected (85% blend) =
        // 5.08:1 — both clear the 4.5:1 normal-text threshold in the
        // shipped light theme.
        labelColor: colors.onPrimary,
        unselectedLabelColor: colors.onPrimary.withValues(alpha: 0.85),
        indicatorColor: colors.onPrimary,
        tabs: [for (final kind in _SafetyKind.values) Tab(text: kind.tabLabel)],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final kind in _SafetyKind.values)
            _SafetyList(key: ValueKey(kind), kind: kind, svc: _svc),
        ],
      ),
    );
  }
}

class _SafetyList extends StatefulWidget {
  const _SafetyList({super.key, required this.kind, required this.svc});
  final _SafetyKind kind;
  final SafetyService svc;

  @override
  State<_SafetyList> createState() => _SafetyListState();
}

class _SafetyListState extends State<_SafetyList> {
  List<int>? _ids;
  final Map<int, Map<String, String?>?> _names = {};
  String? _error;
  bool _loading = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _label => widget.kind.noun;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<int> ids;
      switch (widget.kind) {
        case _SafetyKind.blocked:
          ids = await widget.svc.listBlocked();
          break;
        case _SafetyKind.muted:
          ids = await widget.svc.listMuted();
          break;
        case _SafetyKind.restricted:
          ids = await widget.svc.listRestricted();
          break;
      }
      if (!mounted) return;
      setState(() => _ids = ids);
      for (final id in ids) {
        widget.svc.lookupUser(id).then((info) {
          if (!mounted) return;
          setState(() => _names[id] = info);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove from $_label?'),
        content: Text('This user will no longer be $_label.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busyId = id);
    try {
      switch (widget.kind) {
        case _SafetyKind.blocked:
          await widget.svc.unblock(id);
          break;
        case _SafetyKind.muted:
          await widget.svc.unmute(id);
          break;
        case _SafetyKind.restricted:
          await widget.svc.unrestrict(id);
          break;
      }
      if (!mounted) return;
      setState(() => _ids?.remove(id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final ids = _ids ?? const [];
    if (ids.isEmpty) {
      return Center(child: Text('No $_label users.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: ids.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final id = ids[index];
          final info = _names[id];
          final title = info?['displayName'] ?? info?['username'] ?? 'User #$id';
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(title),
            subtitle: info?['username'] != null ? Text('@${info!['username']}') : null,
            trailing: _busyId == id
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(onPressed: () => _remove(id), child: const Text('Remove')),
          );
        },
      ),
    );
  }
}
