/// The app's single- and multi-select dropdowns (CLAUDE.md §7), ported from
/// mobo_todo so every Mobo app shares one look: a filled field that opens a
/// panel anchored directly beneath it. Every picker in the app goes through
/// [MoboSingleSelectField] or [MoboMultiSelectField] — fixed lists pass
/// `options`, Odoo many2one fields pass `search`.
library;

import 'dart:async';
import '../toggles/mobo_checkbox.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import 'mobo_form_field.dart';

/// Where an anchored dropdown panel should sit, and how tall it may be.
///
/// Recomputed on every overlay build rather than captured when the panel
/// opens: the field moves as the form scrolls and the keyboard comes and
/// goes, and a direction/height decided once would leave the panel hanging
/// off the screen or hidden behind the keyboard.
class _PanelGeometry {
  final double width;
  final bool openUpwards;
  final double maxHeight;

  /// Set when neither side of the field has room for a usable panel — a phone
  /// in landscape with the keyboard up leaves a field a few dozen dp above and
  /// below it. The panel then stops anchoring to the field and sits at the top
  /// of the visible area, over the field: this is how far below the field's top
  /// edge its top edge goes (negative = above). Only for panels that carry
  /// their own search box, so nothing the user is typing into gets hidden.
  final double? coverShift;

  const _PanelGeometry({
    required this.width,
    required this.openUpwards,
    required this.maxHeight,
    this.coverShift,
  });

  /// Gap between the field and its panel.
  static const double gap = 6;

  /// Below this there is not enough room to be worth opening downward.
  static const double _minPanelHeight = 180;

  /// Below this a window counts as short (a phone in landscape): the panel's
  /// height floor drops so it is never taller than the room there is.
  static const double _shortWindow = 500;

  /// Shortest a panel may get on a short window: a row or so, still scrollable.
  static const double _minShortPanelHeight = 56;

  /// Under this, a panel on a short window is cramped enough to be worth
  /// scrolling the field up for (see `_scrollFieldUpIfCramped`).
  static const double crampedPanelHeight = 140;

  /// A panel with its own header needs this much beside the field before it is
  /// worth anchoring there rather than covering the field.
  static const double _minHeaderedPanelHeight = 110;

  /// Measures the field at [context] against the space around it in [media].
  static _PanelGeometry of(
    BuildContext context,
    MediaQueryData media, {
    bool mayCoverField = false,
  }) {
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? media.size.width;
    final fieldHeight = box?.size.height ?? 0;
    final fieldTop = box?.hasSize == true
        ? box!.localToGlobal(Offset.zero).dy
        : 0.0;

    // The keyboard counts as used space: a panel that opened down behind it
    // would hide the very results being searched for.
    final bottomEdge =
        media.size.height - media.padding.bottom - media.viewInsets.bottom;
    final spaceBelow = bottomEdge - (fieldTop + fieldHeight);
    final spaceAbove = fieldTop - media.padding.top;

    // A field low on a scrolling form has nothing below it, and a panel
    // that always dropped downward would hang off the bottom.
    final openUpwards =
        spaceBelow < _minPanelHeight + gap && spaceAbove > spaceBelow;

    // Never taller than the room actually available on the chosen side, so
    // the panel scrolls internally instead of overflowing.
    final available = (openUpwards ? spaceAbove : spaceBelow) - gap - 8;

    if (media.size.height < _shortWindow) {
      if (mayCoverField && available < _minHeaderedPanelHeight) {
        final top = media.padding.top + 8;
        final bottom = bottomEdge - 8;
        return _PanelGeometry(
          width: width,
          openUpwards: false,
          maxHeight: (bottom - top).clamp(96.0, 320.0),
          coverShift: top - fieldTop,
        );
      }

      // The regular floor would push a panel past the screen edge here — a
      // clipped first row, or a list hanging down behind the keyboard.
      return _PanelGeometry(
        width: width,
        openUpwards: openUpwards,
        maxHeight: available.clamp(_minShortPanelHeight, 320.0),
      );
    }

    return _PanelGeometry(
      width: width,
      openUpwards: openUpwards,
      maxHeight: available.clamp(120.0, 320.0),
    );
  }
}

/// What both select fields need while their panel is open: keeping it glued
/// to the field as the form scrolls, and closing it when their page is
/// covered.
mixin _AnchoredPanelHost<W extends StatefulWidget> on State<W> {
  ScrollPosition? _watchedPosition;

  OverlayEntry? get panelOverlay;

  /// The field's own close, with its clean-up.
  void closePanel();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The panel sits in the overlay above every route, so a route pushed
    // over this page — the back button's "Leave?" dialog, a date picker —
    // would open underneath it. ModalRoute.of reruns this when the page
    // stops being the current route; the close waits for the frame to end,
    // as the overlay can't change mid-build.
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent && panelOverlay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && panelOverlay != null) closePanel();
      });
    }
  }

  void startWatchingScroll() {
    _watchedPosition = Scrollable.maybeOf(context)?.position;
    _watchedPosition?.addListener(_remeasure);
  }

  void stopWatchingScroll() {
    _watchedPosition?.removeListener(_remeasure);
    _watchedPosition = null;
  }

  void _remeasure() => panelOverlay?.markNeedsBuild();
}

/// Builds the overlay that hosts a field's panel: a full-screen tap-catcher
/// that closes it, and the panel itself glued to the field through [link].
OverlayEntry _anchoredPanel({
  required BuildContext fieldContext,
  required LayerLink link,
  required VoidCallback onDismiss,
  required Widget Function(double maxHeight) panel,
  bool mayCoverField = false,
  bool leaveFieldTappable = false,
}) {
  return OverlayEntry(
    builder: (overlayContext) {
      // The overlay's own MediaQuery, so the keyboard showing or hiding
      // rebuilds the panel against the space that is left.
      final geometry = _PanelGeometry.of(
        fieldContext,
        MediaQuery.of(overlayContext),
        mayCoverField: mayCoverField,
      );
      final covering = geometry.coverShift != null;

      Widget barrier = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onDismiss,
      );
      if (leaveFieldTappable) {
        // A field that is typed into while its panel is open (the typeable
        // single-select) has controls of its own — the clear-text ✕, the
        // keyboard button — that the full-screen catcher above would swallow,
        // closing the panel instead. A hole where the field sits lets taps
        // reach it; everywhere else still dismisses.
        final fieldBox = fieldContext.findRenderObject() as RenderBox?;
        final overlayBox =
            Overlay.maybeOf(overlayContext)?.context.findRenderObject()
                as RenderBox?;
        if (fieldBox != null &&
            fieldBox.hasSize &&
            overlayBox != null &&
            overlayBox.hasSize) {
          final hole =
              overlayBox.globalToLocal(fieldBox.localToGlobal(Offset.zero)) &
              fieldBox.size;
          barrier = ClipPath(clipper: _HoleClipper(hole), child: barrier);
        }
      }

      return Stack(
        children: [
          Positioned.fill(child: barrier),
          Positioned(
            width: geometry.width,
            child: CompositedTransformFollower(
              link: link,
              showWhenUnlinked: false,
              // Anchoring the panel's bottom edge to the field's top edge is
              // what makes it grow upward rather than down.
              targetAnchor: covering || geometry.openUpwards
                  ? Alignment.topLeft
                  : Alignment.bottomLeft,
              followerAnchor: !covering && geometry.openUpwards
                  ? Alignment.bottomLeft
                  : Alignment.topLeft,
              offset: Offset(
                0,
                covering
                    ? geometry.coverShift!
                    : geometry.openUpwards
                    ? -_PanelGeometry.gap
                    : _PanelGeometry.gap,
              ),
              child: panel(geometry.maxHeight),
            ),
          ),
        ],
      );
    },
  );
}

/// Everything but [hole] — what a tap-catcher with a hole in it is clipped to.
/// Hit testing honours the clip, so a tap inside the hole falls through.
class _HoleClipper extends CustomClipper<Path> {
  final Rect hole;

  const _HoleClipper(this.hole);

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRect(hole);

  @override
  bool shouldReclip(_HoleClipper oldClipper) => oldClipper.hole != hole;
}

/// One selectable option in a [MoboMultiSelectField] or
/// [MoboSingleSelectField].
class MoboSelectOption<T> {
  final T value;
  final String label;

  /// Optional leading visual — an avatar for a person, say.
  final Widget? leading;

  /// For a status: the closed [MoboSingleSelectField] shows this option as a
  /// small pill — a dot and the label in this colour on a pale tint of it —
  /// rather than plain text. The list of options stays plain.
  final Color? badgeColor;

  const MoboSelectOption({
    required this.value,
    required this.label,
    this.leading,
    this.badgeColor,
  });
}

/// A multi-select field (§7).
///
/// The closed field shows the selected values as pill chips — pale primary
/// tint, radius 20, a 35%-alpha primary border, each with a close icon — plus
/// a trailing arrow. Past [maxVisibleChips] (or the width of the field) the
/// remainder collapses into a plain brand-coloured `+N More` label, with no
/// capsule, so the field can't grow without bound.
///
/// Tapping opens a panel anchored directly beneath the field: a title, an
/// optional search box, a right-aligned "Done" (with a left-aligned "Clear"
/// while anything is ticked) above a divider, then the options with a
/// **square** checkbox on the trailing edge. Picks are applied on Done;
/// tapping outside the panel discards them.
class MoboMultiSelectField<T> extends StatefulWidget {
  final String? label;
  final bool isRequired;
  final String hintText;
  final List<MoboSelectOption<T>> options;
  final List<T> selected;
  final ValueChanged<List<T>> onChanged;
  final String? errorText;

  /// Title of the picker panel. Defaults to the field's own label.
  final String? panelTitle;

  /// Hard cap on visible chips, on top of what actually fits on one line.
  final int maxVisibleChips;

  /// Adds a search box to the panel, for long option lists.
  final bool searchable;

  const MoboMultiSelectField({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
    this.isRequired = false,
    this.hintText = 'Select',
    this.errorText,
    this.panelTitle,
    this.maxVisibleChips = 3,
    this.searchable = true,
  });

  @override
  State<MoboMultiSelectField<T>> createState() =>
      _MoboMultiSelectFieldState<T>();
}

class _MoboMultiSelectFieldState<T> extends State<MoboMultiSelectField<T>>
    with _AnchoredPanelHost<MoboMultiSelectField<T>> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;

  @override
  OverlayEntry? get panelOverlay => _overlay;

  bool get _isOpen => _overlay != null;

  @override
  void closePanel() => _close();

  @override
  void didUpdateWidget(covariant MoboMultiSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The open panel lives in the overlay, outside this subtree: options
    // that arrive while it is open (event tags loading, say) only reach it
    // once it is rebuilt — after this frame, as it can't be marked dirty
    // mid-build.
    if (_isOpen) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _overlay?.markNeedsBuild(),
      );
    }
  }

  @override
  void dispose() {
    stopWatchingScroll();
    // Removed directly rather than through _close(), which calls setState.
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  void _toggle() {
    if (_isOpen) {
      _close();
      return;
    }

    // A keyboard left open by another field would squeeze the panel.
    FocusScope.of(context).unfocus();

    _overlay = _anchoredPanel(
      fieldContext: context,
      link: _link,
      onDismiss: _close,
      mayCoverField: true,
      panel: (maxHeight) => _MoboMultiSelectPanel<T>(
        title: widget.panelTitle ?? widget.label ?? 'Select',
        options: widget.options,
        initiallySelected: widget.selected,
        searchable: widget.searchable,
        maxHeight: maxHeight,
        onDone: (values) {
          widget.onChanged(values);
          _close();
        },
      ),
    );

    Overlay.of(context).insert(_overlay!);
    startWatchingScroll();
    setState(() {});
  }

  void _close() {
    stopWatchingScroll();
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chosen = widget.options
        .where((o) => widget.selected.contains(o.value))
        .toList();

    return CompositedTransformTarget(
      link: _link,
      child: MoboFieldShell(
        label: widget.label,
        isRequired: widget.isRequired,
        errorText: widget.errorText,
        isFocused: _isOpen,
        onTap: _toggle,
        child: Row(
          children: [
            Expanded(
              child: chosen.isEmpty
                  ? Text(
                      widget.hintText,
                      style: AppTheme.fieldHintStyle(isDark),
                    )
                  : _ChipRow(
                      options: chosen,
                      maxVisibleChips: widget.maxVisibleChips,
                      onRemove: (value) => widget.onChanged(
                        widget.selected.where((v) => v != value).toList(),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // The thin-stroke chevron mobo Billing's create-invoice form
            // uses, not Material's heavier filled triangle.
            HugeIcon(
              icon: _isOpen
                  ? HugeIcons.strokeRoundedArrowUp01
                  : HugeIcons.strokeRoundedArrowDown01,
              size: 22,
              color: AppTheme.iconColor(isDark),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays the selected chips out on a **single line**, collapsing whatever
/// does not fit into a `+N More` label.
///
/// Measuring means the collapse point follows the actual labels, so a few
/// long tag names collapse as readily as many short ones.
class _ChipRow extends StatelessWidget {
  final List<MoboSelectOption<dynamic>> options;
  final int maxVisibleChips;
  final void Function(dynamic value) onRemove;

  const _ChipRow({
    required this.options,
    required this.maxVisibleChips,
    required this.onRemove,
  });

  /// Rendered width of a selected chip carrying [label]: _SelectedChip's own
  /// padding (10 each side), the 4px gap, the 14px close icon and the 1px
  /// border on either side.
  static double _chipWidth(String label, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      maxLines: 1,
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + 10 + 4 + 14 + 10 + 2;
  }

  /// Rendered width of the `+N More` label (4px of padding each side, as
  /// [_OverflowChip] has; it has no capsule around it).
  static double _overflowWidth(int count, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(
        text: '+$count More',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      maxLines: 1,
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + 8;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    const spacing = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;

        var fitCount = 0;
        var used = 0.0;

        for (var i = 0; i < options.length && i < maxVisibleChips; i++) {
          final width = _chipWidth(options[i].label, scaler);
          final needed = used + (i == 0 ? 0 : spacing) + width;

          // Room must be left for the capsule whenever anything would be
          // hidden, or it would be the thing that overflows.
          final hiddenAfterThis = options.length - (i + 1);
          final reserve = hiddenAfterThis > 0
              ? spacing + _overflowWidth(hiddenAfterThis, scaler)
              : 0.0;

          if (needed + reserve > available) break;
          used = needed;
          fitCount = i + 1;
        }

        // Always show at least one chip: an empty field reading only
        // "+5 More" says less than a name plus a count.
        if (fitCount == 0) fitCount = 1;

        final visible = options.take(fitCount).toList();
        final hidden = options.length - visible.length;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(width: spacing),
              Flexible(
                child: _SelectedChip(
                  label: visible[i].label,
                  leading: visible[i].leading,
                  onRemove: () => onRemove(visible[i].value),
                ),
              ),
            ],
            if (hidden > 0) ...[
              const SizedBox(width: spacing),
              _OverflowChip(count: hidden),
            ],
          ],
        );
      },
    );
  }
}

/// The capsule a selected value is drawn in (§7): pale primary tint, radius
/// 20, 35%-alpha primary border. Dark: the deep brand box of an active filter
/// chip — the pale tint would glare on the grey[850] field.
BoxDecoration _tagDecoration(bool isDark) => BoxDecoration(
  color: isDark ? AppTheme.darkActiveFill : AppTheme.primaryTint,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(
    color: isDark
        ? AppTheme.darkActiveBorder
        : AppTheme.primaryColor.withValues(alpha: 0.35),
    width: 1,
  ),
);

/// Text and icon colour on a [_tagDecoration] capsule: the brand colour,
/// lightened in dark mode to stay readable on the deep box.
Color _tagForeground(bool isDark) =>
    isDark ? AppTheme.darkActiveText : AppTheme.primaryColor;

/// A selected value (§7): pale primary tint, radius 20, 35%-alpha primary
/// border, 13px w500 primary text and a close affordance.
class _SelectedChip extends StatelessWidget {
  final String label;
  final Widget? leading;
  final VoidCallback onRemove;

  const _SelectedChip({
    required this.label,
    required this.onRemove,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = _tagForeground(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: _tagDecoration(isDark),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: Icon(Icons.close, size: 14, color: foreground),
          ),
        ],
      ),
    );
  }
}

/// The `+N More` count after the visible chips: plain brand-coloured text in
/// the chips' own 13/w500, with no capsule or fill of its own — it reads as a
/// label for the tags that are folded away, not as one more tag.
class _OverflowChip extends StatelessWidget {
  final int count;

  const _OverflowChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '+$count More',
        maxLines: 1,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _tagForeground(isDark),
        ),
      ),
    );
  }
}

/// The panel's shared chrome: surface, radius, border and height cap.
class _PanelSurface extends StatelessWidget {
  final double maxHeight;
  final Widget child;

  const _PanelSurface({required this.maxHeight, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 4,
      color: isDark ? AppTheme.darkPopupSurface : AppTheme.white,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      // Keeps a tinted first row and the search progress bar inside the
      // rounded corners.
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : AppTheme.divider,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// The panel's title and search box.
class _PanelHeader extends StatelessWidget {
  final String title;
  final bool searchable;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const _PanelHeader({
    required this.title,
    required this.searchable,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOn(isDark),
              ),
            ),
          ),
        ),
        if (searchable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: MoboTextField(
              controller: searchController,
              hintText: 'Search...',
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              onChanged: onSearchChanged,
            ),
          ),
      ],
    );
  }
}

/// "No matches" / a loading spinner / a load failure, in the list's place.
class _PanelMessage extends StatelessWidget {
  final bool loading;
  final String text;

  const _PanelMessage({required this.loading, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      // Tighter on a short window, where the panel itself is only a few rows.
      padding: EdgeInsets.all(context.isShortScreen ? 10 : 24),
      // heightFactor 1: just the message's own height — a plain Center would
      // stretch to the panel's full height for one line of text.
      child: Center(
        heightFactor: 1,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryOn(isDark),
                ),
              ),
      ),
    );
  }
}

/// The multi-select panel anchored under the field.
class _MoboMultiSelectPanel<T> extends StatefulWidget {
  final String title;
  final List<MoboSelectOption<T>> options;
  final List<T> initiallySelected;
  final bool searchable;
  final ValueChanged<List<T>> onDone;

  /// How tall the panel may grow, decided by the space available on
  /// whichever side of the field it opened.
  final double maxHeight;

  const _MoboMultiSelectPanel({
    required this.title,
    required this.options,
    required this.initiallySelected,
    required this.searchable,
    required this.maxHeight,
    required this.onDone,
  });

  @override
  State<_MoboMultiSelectPanel<T>> createState() =>
      _MoboMultiSelectPanelState<T>();
}

class _MoboMultiSelectPanelState<T> extends State<_MoboMultiSelectPanel<T>> {
  late final Set<T> _selected = {...widget.initiallySelected};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static final ButtonStyle _panelActionStyle = TextButton.styleFrom(
    minimumSize: Size.zero,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MoboSelectOption<T>> get _visibleOptions {
    final q = _query.trim().toLowerCase();
    final matching = q.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.label.toLowerCase().contains(q))
              .toList();
    // What was already chosen when the panel opened comes first — kept to
    // that snapshot rather than the live picks, so rows don't jump under
    // the finger as they are ticked.
    final chosen = widget.initiallySelected.toSet();
    return [
      ...matching.where((o) => chosen.contains(o.value)),
      ...matching.where((o) => !chosen.contains(o.value)),
    ];
  }

  Widget _clearButton(bool isDark) => TextButton(
    onPressed: () => setState(_selected.clear),
    style: _panelActionStyle,
    child: Text(
      'Clear',
      style: TextStyle(
        color: AppTheme.textSecondaryOn(isDark),
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
    ),
  );

  Widget _doneButton() => TextButton(
    onPressed: () => widget.onDone(_selected.toList()),
    style: _panelActionStyle,
    child: const Text(
      'Done',
      style: TextStyle(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    ),
  );

  /// The header on a short window (a phone in landscape): the title, search box
  /// and Done would stack to ~130dp — most of a panel that may only get 150 —
  /// so they share one row. The search box (or the title, when there is none)
  /// takes the room the buttons leave.
  Widget _compactHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: widget.searchable
                ? MoboTextField(
                    controller: _searchController,
                    hintText: 'Search...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  )
                : Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOn(isDark),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          if (_selected.isNotEmpty) _clearButton(isDark),
          _doneButton(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = _visibleOptions;
    final compact = context.isShortScreen;

    return _PanelSurface(
      maxHeight: widget.maxHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact)
            _compactHeader(isDark)
          else ...[
            _PanelHeader(
              title: widget.title,
              searchable: widget.searchable,
              searchController: _searchController,
              onSearchChanged: (value) => setState(() => _query = value),
            ),
            // Done on the right, above a divider, so the picks only apply once
            // the user says so. Clear sits opposite it while anything is ticked
            // and, like the ticks, only empties the panel until Done.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  if (_selected.isNotEmpty) _clearButton(isDark),
                  const Spacer(),
                  _doneButton(),
                ],
              ),
            ),
          ],
          Divider(
            height: 1,
            color: isDark ? Colors.grey[800] : AppTheme.divider,
          ),
          Flexible(
            child: options.isEmpty
                ? const _PanelMessage(loading: false, text: 'No matches')
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final checked = _selected.contains(option.value);

                      return InkWell(
                        onTap: () => setState(() {
                          if (checked) {
                            _selected.remove(option.value);
                          } else {
                            _selected.add(option.value);
                          }
                        }),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: compact ? 9 : 12,
                          ),
                          child: Row(
                            children: [
                              if (option.leading != null) ...[
                                option.leading!,
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.textPrimaryOn(isDark),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // The row handles the tap.
                              IgnorePointer(
                                child: MoboCheckbox(
                                  value: checked,
                                  onChanged: (_) {},
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A single-select field sharing the multi-select's shell.
///
/// Closes on pick and shows the chosen value as text rather than a chip. Its
/// panel is only ever the list of options — no title, no search box: a long
/// or server-backed list is filtered by typing straight into the field,
/// which turns into a text box while the panel is open.
///
/// Two sources of options:
/// - [options] — a fixed list (time zones, visibility, a question type…);
///   [searchable] makes the field typeable for the long ones;
/// - [search] — an Odoo many2one too long to load up front (partners,
///   users, events…): called with what has been typed, debounced, while
///   [selectedLabel] names the current value in the closed field.
class MoboSingleSelectField<T> extends StatefulWidget {
  final String? label;
  final bool isRequired;
  final String hintText;
  final List<MoboSelectOption<T>> options;
  final T? selected;
  final ValueChanged<T?> onChanged;
  final String? errorText;

  /// Announced by screen readers for the options panel, which has no
  /// visible title.
  final String? panelTitle;

  /// Makes a long fixed list typeable: what is typed filters [options].
  final bool searchable;

  /// Loads the options from the server instead of [options]. Called with
  /// what has been typed into the field — empty when the panel first opens.
  final Future<List<MoboSelectOption<T>>> Function(String query)? search;

  /// What the closed field shows for [selected] when it isn't among
  /// [options] — always the case with [search], whose results only exist
  /// while the panel is open.
  final String? selectedLabel;

  /// Shown at the leading edge of the closed field.
  final Widget? prefixIcon;

  /// Whether a chosen value can be cleared from the closed field. Turn off
  /// for a field the record cannot be saved without.
  final bool allowClear;

  /// False dims the field and stops it opening — a slot picker before an
  /// event is chosen, say.
  final bool enabled;

  const MoboSingleSelectField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.options = const [],
    this.search,
    this.selectedLabel,
    this.label,
    this.isRequired = false,
    this.hintText = 'Select',
    this.errorText,
    this.panelTitle,
    this.searchable = false,
    this.prefixIcon,
    this.allowClear = true,
    this.enabled = true,
  });

  @override
  State<MoboSingleSelectField<T>> createState() =>
      _MoboSingleSelectFieldState<T>();
}

class _MoboSingleSelectFieldState<T> extends State<MoboSingleSelectField<T>>
    with WidgetsBindingObserver, _AnchoredPanelHost<MoboSingleSelectField<T>> {
  final LayerLink _link = LayerLink();
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  OverlayEntry? _overlay;

  /// Whether the user has asked for the soft keyboard while the panel is open.
  /// Only meaningful on a short window — see [_openedWithoutKeyboard].
  bool _keyboardRequested = false;

  /// Server-search mode only.
  Timer? _debounce;
  List<MoboSelectOption<T>> _results = const [];
  bool _loading = false;
  bool _failed = false;

  /// Bumped per request, and on close, so a slow answer to an old query
  /// can't overwrite the results of a newer one.
  int _request = 0;

  @override
  OverlayEntry? get panelOverlay => _overlay;

  bool get _isOpen => _overlay != null;
  bool get _remote => widget.search != null;

  @override
  void closePanel() => _close();

  /// Long and server-backed lists are filtered by typing into the field;
  /// short fixed lists just open as a plain list.
  bool get _typeable => widget.searchable || _remote;

  String get _query => _queryController.text.trim();

  List<MoboSelectOption<T>> get _visibleOptions {
    final List<MoboSelectOption<T>> matching;
    if (_remote) {
      matching = _results;
    } else {
      final q = _query.toLowerCase();
      matching = q.isEmpty
          ? widget.options
          : widget.options
                .where((o) => o.label.toLowerCase().contains(q))
                .toList();
    }
    return _selectedFirst(matching);
  }

  /// Puts the current value at the top of the list, so it is the first row
  /// seen when the panel opens.
  List<MoboSelectOption<T>> _selectedFirst(List<MoboSelectOption<T>> options) {
    final selected = widget.selected;
    if (selected == null) return options;

    final index = options.indexWhere((o) => o.value == selected);
    if (index == 0) return options;
    if (index > 0) {
      return [
        options[index],
        ...options.take(index),
        ...options.skip(index + 1),
      ];
    }

    // Not among them: a server search needn't return the current record
    // (and has returned nothing while it loads), so it is added back on
    // top until the user types something it doesn't match.
    final label = widget.selectedLabel;
    if (_remote && _query.isEmpty && label != null && label.isNotEmpty) {
      return [MoboSelectOption(value: selected, label: label), ...options];
    }
    return options;
  }

  @override
  void didUpdateWidget(covariant MoboSingleSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An open panel lives in the overlay, outside this subtree, so new
    // options or a new value only reach it once it is rebuilt — after this
    // frame, as it can't be marked dirty mid-build.
    if (_isOpen) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _overlay?.markNeedsBuild(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// The keyboard the user asked for arrives, and shrinks the page. With the
  /// field up at the top of it (see [_scrollFieldUpIfCramped]) the panel would
  /// have only the page's top margin to open into; the field goes to the
  /// bottom edge of what is left instead, so it has the whole of the rest.
  @override
  void didChangeMetrics() {
    if (!_keyboardRequested || !_isOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen || !_keyboardRequested) return;
      // The overlay's own view of the insets: a Scaffold removes them from
      // everything below it, this field included.
      final keyboard = MediaQuery.viewInsetsOf(
        Overlay.of(context).context,
      ).bottom;
      if (keyboard <= 0) return;
      Scrollable.ensureVisible(context, alignment: 1, duration: Duration.zero);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopWatchingScroll();
    _debounce?.cancel();
    // Removed directly rather than through _close(), which calls setState.
    _overlay?.remove();
    _overlay = null;
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  /// On a short window (a phone in landscape) the soft keyboard takes most of
  /// the screen, so opening the picker does not raise it: the options are what
  /// the user came for, and they get all the room. The field still takes focus
  /// — a hardware keyboard types and filters as usual — but declares no soft
  /// keyboard ([TextInputType.none]) until the keyboard icon is tapped. On any
  /// other window nothing changes.
  bool get _openedWithoutKeyboard =>
      context.isShortScreen && !_keyboardRequested;

  /// The keyboard icon: switch the field to a normal text keyboard and show it,
  /// so the user can type to filter exactly as on a tall screen. The panel
  /// re-measures against the keyboard as soon as it is up.
  void _requestKeyboard() {
    if (!_isOpen) return;
    setState(() => _keyboardRequested = true);
    // After the rebuild, so the platform has the new keyboard type (the field
    // sends it as a config update) before it is asked to show anything.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen) return;
      _queryFocus.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _open() {
    // A keyboard left open by another field would squeeze the panel.
    FocusScope.of(context).unfocus();
    _queryController.clear();
    _keyboardRequested = false;
    if (_remote) {
      _results = const [];
      _failed = false;
      _loading = true;
      _fetch('');
    }

    _overlay = _anchoredPanel(
      fieldContext: context,
      link: _link,
      onDismiss: _close,
      leaveFieldTappable: _typeable,
      panel: (maxHeight) => Semantics(
        container: true,
        label: widget.panelTitle ?? widget.label,
        child: _MoboSingleSelectPanel<T>(
          options: _visibleOptions,
          selected: widget.selected,
          loading: _loading,
          failed: _failed,
          maxHeight: maxHeight,
          onPicked: (value) {
            widget.onChanged(value);
            _close();
          },
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
    startWatchingScroll();
    setState(() {});
    _scrollFieldUpIfCramped();
  }

  /// A field in the middle of a short window leaves the panel only a couple of
  /// rows either side of it. If the page behind can scroll, bring the field up
  /// to the top of it: the panel then has the rest of the window to open into.
  /// The panel follows the scroll (see [_AnchoredPanelHost.startWatchingScroll]).
  void _scrollFieldUpIfCramped() {
    if (!context.isShortScreen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen) return;
      final geometry = _PanelGeometry.of(context, MediaQuery.of(context));
      if (geometry.maxHeight >= _PanelGeometry.crampedPanelHeight) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _close() {
    stopWatchingScroll();
    _debounce?.cancel();
    _request++;
    _overlay?.remove();
    _overlay = null;
    _queryFocus.unfocus();
    _queryController.clear();
    _keyboardRequested = false;
    if (mounted) setState(() {});
  }

  void _onQueryChanged(String _) {
    // Swaps the trailing icon between the clear-typing ✕ and the arrow.
    setState(() {});
    if (_remote) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (!mounted || !_isOpen) return;
        _loading = true;
        _overlay?.markNeedsBuild();
        _fetch(_query);
      });
    }
    _overlay?.markNeedsBuild();
  }

  Future<void> _fetch(String query) async {
    final request = ++_request;
    try {
      final results = await widget.search!(query);
      if (!mounted || request != _request) return;
      _results = results;
      _loading = false;
      _failed = false;
    } catch (_) {
      // The panel only says "Couldn't load options", whatever the cause.
      if (!mounted || request != _request) return;
      _loading = false;
      _failed = true;
    }
    _overlay?.markNeedsBuild();
  }

  void _clearQuery() {
    _queryController.clear();
    _onQueryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    MoboSelectOption<T>? chosen;
    for (final option in widget.options) {
      if (option.value == widget.selected) {
        chosen = option;
        break;
      }
    }
    final label =
        chosen?.label ??
        (widget.selected != null ? widget.selectedLabel : null);
    final hasValue = label != null && label.isNotEmpty;
    final typing = _isOpen && _typeable;
    final noSoftKeyboard = typing && _openedWithoutKeyboard;
    final clearColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final Widget trailing;
    if (typing && _queryController.text.isNotEmpty) {
      // Clears what was typed, not the value.
      trailing = _TrailingIcon(
        icon: Icons.close,
        color: clearColor,
        onTap: _clearQuery,
      );
    } else if (!typing && hasValue && widget.allowClear && widget.enabled) {
      // With a value present, clearing is the action worth one tap —
      // reopening the list is what tapping the field already does.
      trailing = _TrailingIcon(
        icon: Icons.close,
        color: clearColor,
        onTap: () {
          widget.onChanged(null);
          if (_isOpen) _close();
        },
      );
    } else {
      // The thin-stroke chevron mobo Billing's create-invoice form uses,
      // not Material's heavier filled triangle.
      trailing = _TrailingIcon(
        hugeIcon: _isOpen
            ? HugeIcons.strokeRoundedArrowUp01
            : HugeIcons.strokeRoundedArrowDown01,
        size: 22,
        color: AppTheme.iconColor(isDark),
        onTap: widget.enabled ? (_isOpen ? _close : _open) : null,
      );
    }

    return CompositedTransformTarget(
      link: _link,
      child: MoboFieldShell(
        label: widget.label,
        isRequired: widget.isRequired,
        errorText: widget.errorText,
        isFocused: _isOpen,
        onTap: !widget.enabled
            ? null
            // While typing the field stays open; tapping outside closes it.
            : typing
            ? _queryFocus.requestFocus
            : (_isOpen ? _close : _open),
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                widget.prefixIcon!,
                const SizedBox(width: 10),
              ],
              if (!typing && chosen?.leading != null) ...[
                chosen!.leading!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: typing
                    ? TextField(
                        controller: _queryController,
                        focusNode: _queryFocus,
                        autofocus: true,
                        // null is the default text keyboard.
                        keyboardType: noSoftKeyboard
                            ? TextInputType.none
                            : null,
                        onChanged: _onQueryChanged,
                        textInputAction: TextInputAction.search,
                        cursorColor: AppTheme.primaryColor,
                        style: AppTheme.fieldValueStyle(isDark),
                        decoration: InputDecoration(
                          // The current value stays readable as the hint
                          // until the user types over it.
                          hintText: hasValue ? label : widget.hintText,
                          hintStyle: AppTheme.fieldHintStyle(isDark),
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          // The shell draws the only outline. Every state is
                          // cleared explicitly — a null one falls back to the
                          // theme's inputDecorationTheme, which would draw a
                          // second, inner ring on focus.
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                        ),
                      )
                    : hasValue && chosen?.badgeColor != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: _StatusPill(
                          label: label,
                          color: chosen!.badgeColor!,
                        ),
                      )
                    : Text(
                        hasValue ? label : widget.hintText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hasValue
                            ? AppTheme.fieldValueStyle(isDark)
                            : AppTheme.fieldHintStyle(isDark),
                      ),
              ),
              const SizedBox(width: 8),
              if (noSoftKeyboard) ...[
                Semantics(
                  button: true,
                  label: 'Show keyboard',
                  child: _TrailingIcon(
                    icon: Icons.keyboard_outlined,
                    color: clearColor,
                    onTap: _requestKeyboard,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// A status shown inside a closed select field: a dot and the label in
/// [color] on a pale tint of it — the §10 badge recipe, with the dot.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tappable icon at a field's trailing edge. With no [onTap] the tap
/// falls through to the field itself. Pass exactly one of [icon] (a Material
/// glyph — the clear-text ✕, the keyboard toggle) or [hugeIcon] (the
/// dropdown arrow, drawn like mobo Billing's create-invoice form).
class _TrailingIcon extends StatelessWidget {
  final IconData? icon;
  final List<List<dynamic>>? hugeIcon;
  final Color? color;
  final double size;
  final VoidCallback? onTap;

  const _TrailingIcon({
    this.icon,
    this.hugeIcon,
    this.color,
    this.size = 20,
    this.onTap,
  }) : assert(
         (icon == null) != (hugeIcon == null),
         'pass exactly one of icon or hugeIcon',
       );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: hugeIcon != null
            ? HugeIcon(icon: hugeIcon!, size: size, color: color)
            : Icon(icon, size: size, color: color),
      ),
    );
  }
}

/// The single-select panel: only the options — no title, no search box.
class _MoboSingleSelectPanel<T> extends StatelessWidget {
  final List<MoboSelectOption<T>> options;
  final T? selected;
  final bool loading;
  final bool failed;
  final double maxHeight;
  final ValueChanged<T?> onPicked;

  const _MoboSingleSelectPanel({
    required this.options,
    required this.selected,
    required this.loading,
    required this.failed,
    required this.maxHeight,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppTheme.primaryColor;
    // Shorter rows on a short window, so a panel squeezed in beside the
    // keyboard still shows more than one.
    final compact = context.isShortScreen;

    return _PanelSurface(
      maxHeight: maxHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A thin bar while a new search runs over results already shown,
          // so the list doesn't blank out between keystrokes.
          if (loading && options.isNotEmpty)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppTheme.primaryColor,
              backgroundColor: Colors.transparent,
            ),
          Flexible(
            child: options.isEmpty
                ? _PanelMessage(
                    loading: loading,
                    text: failed ? "Couldn't load options" : 'No matches',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option.value == selected;

                      return InkWell(
                        // Single-select commits immediately; there is no
                        // Done step to confirm one choice.
                        onTap: () => onPicked(option.value),
                        child: Container(
                          // The selected row is tinted and its label takes
                          // the brand colour, so the current value is obvious
                          // without scanning the trailing edge.
                          color: isSelected
                              ? (isDark
                                    ? primary.withValues(alpha: 0.18)
                                    : AppTheme.primaryTint)
                              : Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: compact ? 9 : 12,
                          ),
                          child: Row(
                            children: [
                              if (option.leading != null) ...[
                                option.leading!,
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? primary
                                        : AppTheme.textPrimaryOn(isDark),
                                  ),
                                ),
                              ),
                              // Only the selected row carries a trailing
                              // mark: a filled primary disc with a white
                              // check.
                              if (isSelected)
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
