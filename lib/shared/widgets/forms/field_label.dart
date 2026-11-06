import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../toggles/mobo_checkbox.dart';

/// Standard field label (CLAUDE.md §6): grey label text with a **red bold**
/// `" *"` suffix when the field is required.
///
/// The asterisk must never be baked into the label string itself — it needs
/// its own colour, which a plain `Text("Foo *")` can't give it.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool isRequired;

  /// Overrides the base label style. Defaults to [AppTheme.fieldLabelStyle].
  final TextStyle? style;

  /// Space kept under the label, between it and its field. A label that is
  /// laid out by [spacedFormChildren] passes [AppTheme.labelGap] so the card
  /// doesn't also pad it (which doubled the gap).
  final double bottomGap;

  const FieldLabel(
    this.text, {
    super.key,
    this.isRequired = false,
    this.style,
    this.bottomGap = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = style ?? AppTheme.fieldLabelStyle(isDark);

    // Text.rich, not a bare RichText: RichText paints exactly the TextStyle
    // it is given and never consults the ambient theme, so a style with no
    // fontFamily of its own (every field label's) fell back to the platform
    // default (Roboto on Android) instead of the app's Manrope — the same
    // weight number, but visibly heavier letterforms. Text.rich is Text's own
    // rich-text constructor: it merges with DefaultTextStyle like any other
    // Text, which is what actually carries Manrope down from the theme.
    final label = Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text),
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: StatusColors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
    if (bottomGap == 0) return label;
    return Padding(padding: EdgeInsets.only(bottom: bottomGap), child: label);
  }
}

/// Lays a form card's children one under another with billing's rhythm.
///
/// Every child used to get 10px below it, the label included, on top of the
/// label's own 8 — so a label sat 18px above its field but only 10px below
/// the previous one, and looked like it belonged to that one. Now a
/// [FieldLabel] is left to its own [FieldLabel.bottomGap], and whatever comes
/// right before a label gets [AppTheme.fieldGap]. Everything else keeps 10px.
///
/// The exception is a toggle row — a [MoboCheckboxTile], or a
/// [FormToggleGroup] of one with something hanging off it. A tile carries its
/// own padding under its box, so that counts towards the gap: followed by a
/// label ("Limit registration" → "Registration Limit"), the gap is topped up
/// to put 16 between the box and the label, the same as between two fields
/// (a full [AppTheme.fieldGap] on top of the tile's padding made the field look
/// like a separate item, and none at all left it cramped). Followed by another
/// toggle row there is no gap at all: the two tiles' own padding is the room
/// between their boxes.
///
/// The last child gets no gap after it: the card's own padding is the whole
/// space under its content (it used to be that plus a trailing 10).
List<Widget> spacedFormChildren(List<Widget> children) {
  bool isToggle(Widget w) => w is MoboCheckboxTile || w is FormToggleGroup;

  double gapAfter(int i) {
    final next = children[i + 1];
    if (next is FieldLabel) {
      return isToggle(children[i])
          ? AppTheme.fieldGap - _toggleBottomPadding(children[i])
          : AppTheme.fieldGap;
    }
    if (isToggle(children[i]) && isToggle(next)) return 0;
    return 10;
  }

  return [
    for (var i = 0; i < children.length; i++)
      if (children[i] is FieldLabel || i == children.length - 1)
        children[i]
      else
        Padding(
          padding: EdgeInsets.only(bottom: gapAfter(i)),
          child: children[i],
        ),
  ];
}

/// Padding for the form's checkbox rows. Tighter than a tile's default 10, so
/// two toggles stacked in a card (Multiple Slot, Limit registration) sit
/// 12px apart rather than 20 — still a full-width, 34px-tall tap target.
const formToggleRowPadding = EdgeInsets.symmetric(vertical: 6);

/// How far below its box a toggle row's own padding runs; what the form's gaps
/// are measured from. 0 for a group that ends in something other than a tile.
double _toggleBottomPadding(Widget w) {
  if (w is MoboCheckboxTile) {
    return w.padding.resolve(TextDirection.ltr).bottom;
  }
  if (w is FormToggleGroup && w.children.isNotEmpty) {
    return _toggleBottomPadding(w.children.last);
  }
  return 0;
}

/// A toggle row plus what belongs directly under it (the Multiple Slot row and
/// its "+ Create Slots" button). [spacedFormChildren] treats the whole group as
/// one toggle row and puts no form gap between its members.
class FormToggleGroup extends StatelessWidget {
  final List<Widget> children;

  const FormToggleGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
}

/// The grey rule under a form card's heading.
Widget formCardDivider(bool isDark) =>
    Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey.shade200);

/// A form card's heading and the rule under it, with the same 16px above the
/// title as below it — the rule sits right under that bottom padding, with no
/// extra room of its own. [formCardBody]'s 16px then runs from the rule to the
/// first label, so the heading reads as an evenly padded band.
Widget formCardHeader(String title, bool isDark) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? AppTheme.white : AppTheme.textPrimary,
        ),
      ),
    ),
    formCardDivider(isDark),
  ],
);

/// The padded body of a form card, as in mobo Billing's `MoboFormCard`: 16px
/// all round, with [spacedFormChildren] inside and nothing added after the
/// last one.
///
/// A card that ends in a checkbox row is the one exception: that row already
/// carries its own padding under its box, so that much comes off the bottom to
/// keep the card's edge 16px from the box rather than 16 plus the padding.
Widget formCardBody(List<Widget> children) {
  final tail = children.isEmpty ? 0.0 : _toggleBottomPadding(children.last);
  return Padding(
    padding: EdgeInsets.fromLTRB(16, 16, 16, (16 - tail).clamp(0.0, 16.0)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spacedFormChildren(children),
    ),
  );
}
