import 'package:flutter/material.dart';

import 'package:furtail_app/features/posts/data/models/feeling_activity_model.dart';

/// Rich modal bottom sheet for selecting a feeling or activity item.
///
/// Shows a searchable, categorized list of emoji + label items.
/// Accepts a pre-loaded [items] list (fetched from API or fallback).
/// Returns the selected [FeelingActivityItem] or null if dismissed.
class FeelingActivityPicker extends StatefulWidget {
  final String title;
  final String type;
  final List<FeelingActivityItem> items;

  const FeelingActivityPicker({
    super.key,
    required this.items,
    this.title = 'How are you feeling?',
    this.type = 'feeling',
  });

  @override
  State<FeelingActivityPicker> createState() => _FeelingActivityPickerState();
}

class _FeelingActivityPickerState extends State<FeelingActivityPicker> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FeelingActivityItem> get _allItems => widget.items;

  List<FeelingActivityItem> get _filteredItems {
    if (_query.isEmpty) return _allItems;
    final q = _query.toLowerCase();
    return _allItems.where((item) {
      return item.label.toLowerCase().contains(q) ||
          item.emoji.contains(q) ||
          item.category.toLowerCase().contains(q);
    }).toList();
  }

  /// Returns unique category names in the items list, preserving order.
  List<String> get _categories {
    final seen = <String>{};
    final result = <String>[];
    for (final item in _allItems) {
      if (seen.add(item.category)) {
        result.add(item.category);
      }
    }
    return result;
  }

  List<FeelingActivityItem> _itemsForCategory(String category) {
    return _allItems.where((item) => item.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: Column(
          children: [
            // ── Drag handle ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 38, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E6E6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            // ── Title ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            // ── Search box ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search feelings & activities…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Items list ───────────────────────────────────────────
            Expanded(
              child: _query.isNotEmpty
                  ? _buildSearchResults(scrollController)
                  : _buildCategorizedList(scrollController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorizedList(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        for (final category in _categories)
          ..._buildCategory(category),
      ],
    );
  }

  List<Widget> _buildCategory(String category) {
    final items = _itemsForCategory(category);
    if (items.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(
          category,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      ...items.map((item) => _buildItemRow(item)),
    ];
  }

  Widget _buildSearchResults(ScrollController controller) {
    final results = _filteredItems;
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No results found',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ),
      );
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            '${results.length} result${results.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
        ...results.map((item) => _buildItemRow(item)),
      ],
    );
  }

  Widget _buildItemRow(FeelingActivityItem item) {
    return ListTile(
      dense: true,
      leading: Text(item.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(
        item.label,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        item.type == 'FEELING' ? 'Feeling' : 'Activity',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          item.category,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ),
      onTap: () => Navigator.pop(context, item),
    );
  }
}

/// Convenience function: fetches items from API (with fallback),
/// then shows the picker. Returns selected item or null.
Future<FeelingActivityItem?> showFeelingActivityPicker(
  BuildContext context, {
  String title = 'How are you feeling?',
  String type = 'feeling',
  List<FeelingActivityItem>? items,
}) {
  return showModalBottomSheet<FeelingActivityItem>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => FeelingActivityPicker(
      title: title,
      type: type,
      items: items ?? FeelingActivityItem.all, // fallback to hardcoded
    ),
  );
}
