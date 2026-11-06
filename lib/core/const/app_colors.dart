/// Legacy top-level colour aliases.
///
/// These now delegate to [AppTheme] (CLAUDE.md §1) so the palette has exactly
/// one definition. Prefer referencing `AppTheme.*` / `StatusColors.*` directly
/// in new code — these aliases exist only for the screens that already use them.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand colour — see [AppTheme.primaryColor].
const Color primaryColor = AppTheme.primaryColor;

/// Surfaces (light mode) — see [AppTheme.white].
const Color whiteColor = AppTheme.white;

/// Generic light background — see [AppTheme.background].
const Color backgroundColor = AppTheme.background;

/// Filled input background — see [AppTheme.fieldFill].
const Color fillColor = AppTheme.fieldFill;

/// Primary text — see [AppTheme.textPrimary].
const Color blackColor = AppTheme.textPrimary;

/// Gold used by the star rating control — see [AppTheme.ratingStar].
const Color ratingStarColor = AppTheme.ratingStar;

/// Near-black used by primary action buttons on light surfaces.
const Color darkColor = AppTheme.dark;

/// Card surface on dark theme.
const Color darkSurfaceColor = AppTheme.darkSurface;
