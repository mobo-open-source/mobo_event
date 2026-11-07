import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_layout.dart';

/// Heading of a list section (event Tickets / Communication / Questions
/// tabs). When the list has items, [onAdd] puts a compact "Add" pill at the
/// heading's right end — the only add action then, nothing under the list.
/// Leave [onAdd] null while the list is empty: [EmptySectionState] carries
/// the add button in that case.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;

  const SectionHeader({super.key, required this.title, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOn(isDark),
              ),
            ),
          ),
          if (onAdd != null)
            // Outlined, like the app's secondary (Cancel-style) button —
            // primary border/text, no fill — instead of a filled tint pill.
            // Corners are the 12 of the Details screen's Scan to Register
            // button (AppRadius.md), so the two read as the same family rather
            // than one fully-rounded capsule next to a rounded rectangle.
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTheme.primaryColor, width: 1.5),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAdd01,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row of a section list — a ticket, a scheduled mail, a question: a
/// bordered card with no shadow.
///
/// These lists scroll inside the tab's white panel, which clips at its own
/// edges. A shadow there only ever showed as a grey bar under each card with
/// its sides cut off, and a white card on white had no edge of its own, so the
/// rows looked offset. The border draws the card instead, the way kanban cards
/// sit on their column (CLAUDE.md §11). One shell for all three lists keeps
/// their padding, spacing and ripple identical, and puts the delete button
/// ([SectionDeleteButton]) in the same place on each.
///
/// The ripple lives on the card's own [Material], so it shows over the fill
/// (an `InkWell` around a filled `Container` paints it underneath).
class SectionCard extends StatelessWidget {
  final Widget child;

  /// Null leaves the card inert: no ripple, no tap.
  final VoidCallback? onTap;

  const SectionCard({super.key, required this.child, this.onTap});

  /// Space under each card, to the next one.
  static const double gap = 10;

  /// Compact: 14 at the sides, 10 above and below. A card with a ⋮ is as tall
  /// as that button (40) either way, so this is what keeps the rows short.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: gap),
      child: Material(
        color: AppTheme.surface(isDark),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          // The same line the empty state's card draws in this panel.
          side: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The delete action of a [SectionCard], on the Tickets, Communication and
/// Questions lists: a red trash icon, where a ⋮ menu used to be.
///
/// That menu held a single entry, "Delete", so it cost a tap to open and a
/// second to use. The button takes the menu's place — the same footprint, so a
/// card is no taller or wider for it — and [onPressed] is the screen's own
/// delete, which asks for confirmation first.
///
/// The icon is the delete icon mobo CRM's quotation list uses in its
/// row-action menu (`custom_components.dart`).
class SectionDeleteButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SectionDeleteButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Delete',
      padding: EdgeInsets.zero,
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedDelete02,
        color: StatusColors.red,
        size: 20,
      ),
    );
  }
}

/// Gives a section's empty state the whole space the section has, so
/// [EmptySectionState] fills it (portrait) or centres itself in it (landscape)
/// instead of sitting against the top-left corner.
///
/// It scrolls only when the content is taller than that space (a small
/// screen, a large text size), so nothing is ever cut off. Give it a bounded
/// height, e.g. as the child of an `Expanded`; without one it just wraps the
/// content.
class CenteredSectionBody extends StatelessWidget {
  final Widget child;

  const CenteredSectionBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Empty list section: a bordered card holding an icon, a title and a hint,
/// then a full-width brand "Add …" button below them.
///
/// [onAction] is null for an account that may not add to this list: the
/// hint and the button it points at are left off, and only the icon tile and
/// title remain.
///
/// Fills the width it is given, so its content is centred across it. Without
/// that, a scroll view around it hands it loose constraints and the column
/// shrinks to its widest child and sits against the left edge. To centre it
/// vertically as well, wrap it in [CenteredSectionBody].
class EmptySectionState extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  /// A 40-tall button sized to its label and centred under the hint, instead
  /// of the 48-tall one that spans the card.
  final bool compactAction;

  const EmptySectionState({
    super.key,
    required this.icon,
    required this.title,
    required this.actionLabel,
    this.onAction,
    this.compactAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppTheme.inputFill(isDark);
    final muted = AppTheme.secondaryLabelColor(isDark);

    final content = Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 44, color: muted),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryOn(isDark),
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 6),
            Text(
              'Tap "$actionLabel" to get started',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: muted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: compactAction ? 40 : 48,
              // Null lets the Column hand the button loose width, so it sizes
              // to its label and sits centred.
              width: compactAction ? null : double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[500],
                  foregroundColor: Colors.white,
                  // The theme's button padding is vertical-only, which leaves
                  // a label-sized button with no breathing room at its sides.
                  padding: compactAction
                      ? const EdgeInsets.symmetric(horizontal: 20)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: onAction,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  size: 20,
                  color: Colors.white,
                ),
                label: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return SizedBox(
      width: double.infinity,
      // On a phone in landscape (700–900dp wide) the full-width "Add …" button
      // would span the window; there it is capped and centred, at its own height.
      // Portrait fills the space it is given.
      child: context.isLandscape
          ? Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: content,
              ),
            )
          : content,
    );
  }
}
