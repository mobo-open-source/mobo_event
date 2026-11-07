import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/forms/mobo_dropdown_option_tile.dart';

class AppTypeAhead<T> extends StatefulWidget {
  final TextEditingController controller;
  final T? selectedValue;
  final String hint;

  final Future<List<T>> Function(String) suggestionsCallback;
  final String Function(T) itemLabel;
  final void Function(T) onSelected;

  final Widget Function(
    BuildContext context,
    TextEditingController controller,
    FocusNode focusNode,
    bool isSelected,
    VoidCallback? clear,
  )
  fieldBuilder;

  /// Identifies whether a suggestion-list item matches [selectedValue], so
  /// that item can be shown highlighted with a trailing check (CLAUDE.md §7).
  /// Defaults to reference equality, which rarely matches since suggestions
  /// are freshly fetched objects — pass e.g. `(item) => item.id == selected?.id`.
  final bool Function(T item)? isSelected;

  const AppTypeAhead({
    super.key,
    required this.controller,
    required this.hint,
    required this.suggestionsCallback,
    required this.itemLabel,
    required this.onSelected,
    required this.fieldBuilder,
    this.selectedValue,
    this.isSelected,
  });

  @override
  State<AppTypeAhead<T>> createState() => _AppTypeAheadState<T>();
}

class _AppTypeAheadState<T> extends State<AppTypeAhead<T>> {
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<T>(
      hideOnEmpty: false,
      hideOnLoading: false,
      hideOnError: false,
      controller: widget.controller,
      focusNode: focusNode,
      debounceDuration: const Duration(milliseconds: 300),
      suggestionsCallback: widget.suggestionsCallback,

      decorationBuilder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: AppTheme.surface(isDark),
          elevation: 4,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 100, maxHeight: 250),
            child: child,
          ),
        );
      },

      emptyBuilder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: 100,
          child: Center(
            child: Text(
              "No results found",
              style: TextStyle(color: AppTheme.secondaryLabelColor(isDark)),
            ),
          ),
        );
      },

      loadingBuilder: (context) => Container(
        height: 100,
        child: const Center(child: CircularProgressIndicator()),
      ),

      // §7 — dropdown option row: brand-coloured with a trailing check when
      // selected (mirrors mobo_fleet's driver picker).
      itemBuilder: (context, item) {
        return MoboDropdownOptionTile(
          title: widget.itemLabel(item),
          isSelected: widget.isSelected?.call(item) ?? false,
          onTap: () => SuggestionsController.of<T>(context).select(item),
        );
      },

      onSelected: widget.onSelected,

      builder: (context, textController, node) {
        return GestureDetector(
          onTap: () {
            node.requestFocus();
          },
          child: widget.fieldBuilder(
            context,
            textController,
            node,
            widget.selectedValue != null,
            widget.selectedValue != null
                ? () {
                    textController.clear();
                  }
                : null,
          ),
        );
      },
    );
  }
}
