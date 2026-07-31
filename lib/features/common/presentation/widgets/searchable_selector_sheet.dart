import 'package:flutter/material.dart';

/// Async data source for a [SearchableSelectorSheet] — return the full item
/// list (already scoped to whatever parent selection applies); the sheet
/// does client-side search filtering via [SelectorItem.searchTerms].
typedef SelectorLoader<T> = Future<List<T>> Function();

/// One selectable row. [subtitle] is optional (e.g. a Bengali name or
/// alias), [searchTerms] should include every string the user might type
/// (name, alias, code) for the sheet's search box to match against.
class SelectorItem<T> {
  const SelectorItem({
    required this.value,
    required this.label,
    this.subtitle,
    List<String>? searchTerms,
  }) : searchTerms = searchTerms ?? const [];

  final T value;
  final String label;
  final String? subtitle;
  final List<String> searchTerms;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (label.toLowerCase().contains(q)) return true;
    if ((subtitle ?? '').toLowerCase().contains(q)) return true;
    return searchTerms.any((t) => t.toLowerCase().contains(q));
  }
}

/// Shows an accessible, searchable, bounded-height bottom sheet selector.
/// Never covers the whole screen (max 80% of viewport height via
/// [DraggableScrollableSheet]), stays above the keyboard, and supports
/// retry on load failure. Returns the chosen value, or `null` if dismissed
/// without a selection.
Future<T?> showSearchableSelectorSheet<T>({
  required BuildContext context,
  required String title,
  required SelectorLoader<SelectorItem<T>> load,
  T? selectedValue,
  String searchHint = 'Search',
  String emptyMessage = 'No options available.',
  bool Function(T a, T b)? equals,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SelectorSheetBody<T>(
      title: title,
      load: load,
      selectedValue: selectedValue,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
      equals: equals ?? (a, b) => a == b,
    ),
  );
}

class _SelectorSheetBody<T> extends StatefulWidget {
  const _SelectorSheetBody({
    required this.title,
    required this.load,
    required this.selectedValue,
    required this.searchHint,
    required this.emptyMessage,
    required this.equals,
  });

  final String title;
  final SelectorLoader<SelectorItem<T>> load;
  final T? selectedValue;
  final String searchHint;
  final String emptyMessage;
  final bool Function(T a, T b) equals;

  @override
  State<_SelectorSheetBody<T>> createState() => _SelectorSheetBodyState<T>();
}

enum _LoadState { loading, loaded, error }

class _SelectorSheetBodyState<T> extends State<_SelectorSheetBody<T>> {
  _LoadState _state = _LoadState.loading;
  List<SelectorItem<T>> _items = const [];
  String _query = '';
  Object? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _state = _LoadState.loading);
    try {
      final items = await widget.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _state = _LoadState.error;
      });
    }
  }

  List<SelectorItem<T>> get _filtered =>
      _items.where((item) => item.matches(_query)).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          // Keeps the sheet above the on-screen keyboard.
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    textField: true,
                    label: widget.searchHint,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildBody(scrollController)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
      case _LoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 32),
                const SizedBox(height: 8),
                Text(
                  _error == null
                      ? 'Could not load options.'
                      : 'Could not load options. Please try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case _LoadState.loaded:
        final filtered = _filtered;
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.emptyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }
        return ListView.builder(
          controller: scrollController,
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            final isSelected =
                widget.selectedValue != null &&
                widget.equals(item.value, widget.selectedValue as T);
            return Semantics(
              button: true,
              selected: isSelected,
              label: item.subtitle == null
                  ? item.label
                  : '${item.label}, ${item.subtitle}',
              child: ListTile(
                title: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                subtitle: item.subtitle == null
                    ? null
                    : Text(
                        item.subtitle!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                trailing: isSelected ? const Icon(Icons.check_circle) : null,
                selected: isSelected,
                onTap: () => Navigator.of(context).pop(item.value),
              ),
            );
          },
        );
    }
  }
}
