import 'package:flutter/material.dart';

/// The layout every dialog and bottom sheet with a footer button shares: an
/// optional [header] and the [footer] stay pinned, and the [body] between them
/// scrolls and shrinks to whatever height is left.
///
/// That height is what the route hands down — the window minus the keyboard
/// (a phone in landscape is ~360dp tall, with ~100–200dp left once it opens)
/// minus the dialog's own margins — so nothing here needs to know about either.
/// With room to spare the body is simply as tall as its content.
///
/// When even the pinned parts don't fit — below [scrollAllBelow] — the pinned
/// parts stop being pinned and everything scrolls as one page instead. Nothing
/// is cut off or unreachable then; the alternative is a RenderFlex overflow.
/// Set [scrollAllBelow] a little above the height of the header, the footer
/// and one row of the body together.
///
/// Must sit in a bounded-height parent (a [Dialog], a bottom sheet). It uses a
/// [LayoutBuilder], so it can't be a child of an `IntrinsicWidth` (an
/// `AlertDialog`).
class PinnedFooterLayout extends StatefulWidget {
  const PinnedFooterLayout({
    super.key,
    this.header,
    required this.body,
    required this.footer,
    this.gap = 0,
    this.scrollAllBelow = 120,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.expandBody = false,
  });

  /// Stays at the top while the body scrolls.
  final Widget? header;

  /// Scrolls between the header and the footer.
  final Widget body;

  /// Stays at the bottom while the body scrolls — the submit / Cancel row.
  final Widget footer;

  /// Space between the body and the footer.
  final double gap;

  /// The incoming height below which the header and footer scroll too.
  final double scrollAllBelow;

  final CrossAxisAlignment crossAxisAlignment;

  /// True makes the body fill all the height it is given (a sheet of a fixed
  /// size) instead of shrinking to its content.
  final bool expandBody;

  @override
  State<PinnedFooterLayout> createState() => _PinnedFooterLayoutState();
}

class _PinnedFooterLayoutState extends State<PinnedFooterLayout> {
  /// The parts keep their state — a focused text field, above all — when the
  /// keyboard opening takes the layout across
  /// [PinnedFooterLayout.scrollAllBelow] and they move from the pinned
  /// arrangement to the scrolling one.
  ///
  /// Without these keys that move would rebuild them from scratch and drop the
  /// focus the keyboard is open for.
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _bodyKey = GlobalKey();
  final GlobalKey _footerKey = GlobalKey();

  bool? _wasTooShort;

  /// The body moves into a new scroll view when the arrangement changes, which
  /// starts at the top — so the field the keyboard is open for would be left
  /// out of sight. Bring it back into view once the new layout is in place.
  void _revealFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (!mounted || focused == null || !focused.mounted) return;
      if (_bodyKey.currentContext == null) return;
      Scrollable.ensureVisible(
        focused,
        alignment: 0.5,
        duration: Duration.zero,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header == null
        ? null
        : KeyedSubtree(key: _headerKey, child: widget.header!);
    final body = KeyedSubtree(key: _bodyKey, child: widget.body);
    final footer = KeyedSubtree(key: _footerKey, child: widget.footer);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tooShort =
            constraints.hasBoundedHeight &&
            constraints.maxHeight < widget.scrollAllBelow;
        if (_wasTooShort != null && _wasTooShort != tooShort) _revealFocus();
        _wasTooShort = tooShort;

        if (tooShort) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: widget.crossAxisAlignment,
              children: [
                ?header,
                body,
                SizedBox(height: widget.gap),
                footer,
              ],
            ),
          );
        }

        return Column(
          mainAxisSize: widget.expandBody ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: widget.crossAxisAlignment,
          children: [
            ?header,
            Flexible(
              fit: widget.expandBody ? FlexFit.tight : FlexFit.loose,
              child: SingleChildScrollView(child: body),
            ),
            SizedBox(height: widget.gap),
            footer,
          ],
        );
      },
    );
  }
}
