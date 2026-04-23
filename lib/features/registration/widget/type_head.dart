import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

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

  const AppTypeAhead({
    super.key,
    required this.controller,
    required this.hint,
    required this.suggestionsCallback,
    required this.itemLabel,
    required this.onSelected,
    required this.fieldBuilder,
    this.selectedValue,
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
        return Material(
          color: Colors.white,
          elevation: 6,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 100, maxHeight: 250),
            child: child,
          ),
        );
      },

      emptyBuilder: (context) => Container(
        color: Colors.white,
        height: 100,
        child: const Center(child: Text("No results found")),
      ),

      loadingBuilder: (context) => Container(
        color: Colors.white,
        height: 100,
        child: const Center(child: CircularProgressIndicator()),
      ),

      itemBuilder: (context, item) {
        return ListTile(title: Text(widget.itemLabel(item)));
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
