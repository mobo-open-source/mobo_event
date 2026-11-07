import 'package:flutter/widgets.dart';

/// Drops keyboard focus when a full page is pushed on top of the current one,
/// or popped off it.
///
/// A route's focus scope remembers which field had focus, and gives it back
/// when the route is shown again — so a search box tapped on Home brought the
/// keyboard back up on return from any other page. Clearing the focus as the
/// page is pushed means there is nothing left to restore.
///
/// Dialogs and bottom sheets are not pages and are left alone: they are meant
/// to sit over a focused field (and often hold fields of their own).
class UnfocusOnPushObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      // `scope` disposition (the default) also clears the scope's focus
      // history, which is what stops it being restored on return.
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// Same for going back: without this the page being returned to can hand
  /// focus back to a field and reopen the keyboard behind the transition.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }
}
