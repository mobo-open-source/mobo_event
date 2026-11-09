import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The app's list search bar (ported from mobo_fleet's `MoboSearchField` so
/// every list screen — vehicles there, events/attendees here — reads as one
/// system).
///
/// Two separate card-like surfaces sitting side by side: the search field,
/// and a square filter button to its right. Both share a 10px corner radius,
/// are borderless at rest and carry the same soft drop shadow. Focus brings
/// up a brand-coloured ring on the field only.
///
/// The filter button is always rendered, with or without [onFilterTap], so
/// the toolbar never changes shape between screens or between tabs on the
/// same screen; it simply doesn't respond to taps when no handler is wired up.
class MoboSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Called after the field is cleared, so the caller can reload its list.
  final VoidCallback? onClear;

  /// When set, the trailing filter button opens the screen's filter sheet.
  /// With no handler the same button is shown but is purely decorative, so
  /// the toolbar's look never changes based on this.
  final VoidCallback? onFilterTap;

  /// Shows the small primary dot on the filter button.
  final bool hasActiveFilters;

  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Margin kept clear of the caret when the keyboard scrolls the field into
  /// view. The default is Flutter's own.
  final EdgeInsets scrollPadding;

  const MoboSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onFilterTap,
    this.hasActiveFilters = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  @override
  State<MoboSearchField> createState() => _MoboSearchFieldState();
}

class _MoboSearchFieldState extends State<MoboSearchField> {
  /// Plain nullable field, lazily created — deliberately not `late final`
  /// set from [initState]. Hot reload doesn't re-run `initState` for a
  /// `State` object that already existed before the reload, so a `late`
  /// field left unset by the old `initState` body throws on first access;
  /// a nullable field with a `??=` getter just heals itself instead.
  FocusNode? _internalFocusNode;
  bool _hasFocus = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  /// Only the clear affordance depends on emptiness, so rebuild on that edge.
  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
  }

  static const double _height = 48;

  /// Field and button share one corner radius so the two surfaces read as a
  /// matched pair.
  static const double _fieldRadius = 10;
  static const double _buttonRadius = 10;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildField(isDark)),
        const SizedBox(width: 12),
        _buildFilterButton(isDark),
      ],
    );
  }

  Widget _buildField(bool isDark) {
    final hasText = widget.controller.text.isNotEmpty;
    final Color iconColor = AppTheme.hintColor(isDark);

    // Shadow lives on this outer, unclipped box — clipping a decoration
    // also clips its own boxShadow (it paints outside the box's bounds),
    // which is what made the field lose its definition against the page
    // background.
    //
    // The fill and focus ring live one level in, but deliberately as a bare
    // `DecoratedBox`, not a second `Container`: giving a `Container` a
    // `border` makes it auto-pad its child by the border's width
    // (`BoxDecoration.padding => border.dimensions`), even for a fully
    // transparent border — which would shift the field's contents by 2px
    // the moment it takes focus.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_fieldRadius),
        boxShadow: AppShadows.search,
      ),
      child: SizedBox(
        height: _height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(_fieldRadius),
            // 1px resting outline (visible in dark mode only), 2px brand
            // ring on focus — on a DecoratedBox, so the width change never
            // shifts the contents.
            border: Border.all(
              color: _hasFocus
                  ? AppTheme.primaryColor
                  : AppTheme.restingBorderColor(isDark),
              width: _hasFocus ? 2 : 1,
            ),
          ),

          // The icon and the input are laid out by this Row rather than by
          // `InputDecoration`'s prefixIcon. `InputDecorator` derives its own
          // content height from the tallest of (prefix, input, suffix) and
          // then distributes `contentPadding` around that — with a 22px icon
          // against a ~21px line box the two never share a centre line, which
          // is what left the glyph and the text both sitting high in the
          // 48px field. A plain Row with `CrossAxisAlignment.center` centres
          // each child against the same axis, so they line up exactly.
          child: GestureDetector(
            // The Row only fills the field's width, not its tap target — so
            // focus the input when the gaps and the icon are tapped too.
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _focusNode.requestFocus : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search, size: 22, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    scrollPadding: widget.scrollPadding,
                    enabled: widget.enabled,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    cursorColor: AppTheme.primaryColor,

                    // No `height: 1.0` on either style: forcing the line box
                    // down to exactly the font size clips the descenders and
                    // throws the optical centre off. The font's natural line
                    // height keeps the glyphs centred in their own box.
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: AppTheme.hintColor(isDark),
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                        letterSpacing: 0,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,

                      // Fully collapsed: the field contributes nothing but its
                      // own line height, leaving the Row free to centre it.
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (hasText)
                  IconButton(
                    icon: Icon(Icons.clear_rounded, color: iconColor, size: 18),
                    tooltip: 'Clear search',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: widget.enabled
                        ? () {
                            widget.controller.clear();
                            widget.onChanged?.call('');
                            widget.onClear?.call();
                          }
                        : null,
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_buttonRadius),
        boxShadow: AppShadows.search,
      ),
      child: Material(
        color: isDark ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonRadius),
          side: AppTheme.restingBorderSide(isDark),
        ),
        child: InkWell(
          onTap: widget.enabled ? widget.onFilterTap : null,
          borderRadius: BorderRadius.circular(_buttonRadius),
          child: SizedBox(
            width: _height,
            height: _height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 22,
                  color: isDark ? Colors.white70 : const Color(0xFF5F5F5F),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A standalone 40×40 filter button, for a toolbar that keeps the filter
/// action outside the search field.
class MoboFilterIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final bool hasActiveFilters;

  const MoboFilterIconButton({
    super.key,
    required this.onTap,
    this.icon = Icons.filter_list_rounded,
    this.hasActiveFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
            if (hasActiveFilters)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
