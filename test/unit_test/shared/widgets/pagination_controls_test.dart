import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/shared/widgets/pagination/pagination_controls.dart';

void main() {
  // No ripple: the test environment cannot decode Flutter's ink-sparkle shader.
  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: Scaffold(body: Center(child: child)),
  );

  Widget controls({
    required bool canPrevious,
    required bool canNext,
    int? totalCount,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
  }) {
    return Builder(
      builder: (context) => PaginationControls(
        canGoToPreviousPage: canPrevious,
        canGoToNextPage: canNext,
        onPreviousPage: onPrevious ?? () {},
        onNextPage: onNext ?? () {},
        paginationText: '1-20 / 45',
        totalCount: totalCount,
        isDark: false,
        theme: Theme.of(context),
      ),
    );
  }

  Finder arrow(List<List<dynamic>> icon) =>
      find.byWidgetPredicate((w) => w is HugeIcon && w.icon == icon);

  Color? colorOf(WidgetTester tester, List<List<dynamic>> icon) =>
      tester.widget<HugeIcon>(arrow(icon)).color;

  // The InkWell wrapping an arrow: its onTap is null when the arrow is dimmed.
  InkWell inkWellOf(WidgetTester tester, List<List<dynamic>> icon) =>
      tester.widget<InkWell>(
        find.ancestor(of: arrow(icon), matching: find.byType(InkWell)),
      );

  testWidgets('shows no count when there are no records', (tester) async {
    await tester.pumpWidget(
      host(controls(canPrevious: false, canNext: false, totalCount: 0)),
    );

    expect(find.byType(PaginationCounterPill), findsNothing);
    expect(find.byType(HugeIcon), findsNothing);
  });

  testWidgets('shows the count but no arrows when one page holds everything', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(controls(canPrevious: false, canNext: false, totalCount: 7)),
    );

    expect(find.byType(PaginationCounterPill), findsOneWidget);
    expect(find.byType(HugeIcon), findsNothing);
  });

  testWidgets('dims an unusable arrow instead of hiding it, and ignores taps', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(
      host(
        controls(
          canPrevious: false,
          canNext: true,
          totalCount: 45,
          onPrevious: () => previous++,
          onNext: () => next++,
        ),
      ),
    );

    // Both arrows are on screen; only the one with nowhere to go is grey.
    expect(arrow(HugeIcons.strokeRoundedArrowLeft01), findsOneWidget);
    expect(arrow(HugeIcons.strokeRoundedArrowRight01), findsOneWidget);
    expect(
      colorOf(tester, HugeIcons.strokeRoundedArrowLeft01),
      Colors.grey[400],
    );
    expect(colorOf(tester, HugeIcons.strokeRoundedArrowRight01), Colors.black);
    expect(inkWellOf(tester, HugeIcons.strokeRoundedArrowLeft01).onTap, isNull);
    expect(
      inkWellOf(tester, HugeIcons.strokeRoundedArrowRight01).onTap,
      isNotNull,
    );

    await tester.tap(arrow(HugeIcons.strokeRoundedArrowLeft01));
    expect(previous, 0);

    await tester.tap(arrow(HugeIcons.strokeRoundedArrowRight01));
    expect(next, 1);
  });

  testWidgets('dims the last page\'s forward arrow instead', (tester) async {
    await tester.pumpWidget(
      host(controls(canPrevious: true, canNext: false, totalCount: 45)),
    );

    expect(colorOf(tester, HugeIcons.strokeRoundedArrowLeft01), Colors.black);
    expect(
      colorOf(tester, HugeIcons.strokeRoundedArrowRight01),
      Colors.grey[400],
    );
    expect(
      inkWellOf(tester, HugeIcons.strokeRoundedArrowRight01).onTap,
      isNull,
    );
  });

  testWidgets('the row keeps its width whichever arrow is dimmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(controls(canPrevious: false, canNext: true, totalCount: 45)),
    );
    final firstPage = tester.getSize(find.byType(PaginationControls));

    await tester.pumpWidget(
      host(controls(canPrevious: true, canNext: false, totalCount: 45)),
    );
    final lastPage = tester.getSize(find.byType(PaginationControls));

    expect(lastPage, firstPage);
  });
}
