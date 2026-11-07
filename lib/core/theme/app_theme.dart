import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for the Mobo design tokens (see CLAUDE.md §1–§4).
///
/// Nothing in the app should declare a raw Material colour, an ad-hoc shadow or
/// a one-off corner radius — everything routes through [AppTheme],
/// [StatusColors], [AppShadows] and [AppRadius].
class AppTheme {
  /// Brand colour — AppBar, primary buttons, links, selected states, icons.
  static const Color primaryColor = Color(0xFFC03355);

  /// Secondary / contrast colour.
  static const Color secondaryColor = Color(0xFFFFFFFF);

  /// Primary text (light mode).
  static const Color dark = Color(0xFF101010);
  static const Color white = Color(0xFFFFFFFF);

  /// Generic light background.
  static const Color lightGrey = Color(0xFFF3F3F3);
  static const Color background = lightGrey;

  /// Scaffold background (light theme).
  static const Color scaffoldBackground = Color(0xFFFAFAFA);

  static const Color textPrimary = Color(0xFF101010);
  static const Color textSecondary = Color(0xFF666666);
  static const Color divider = Color(0xFFE0E0E0);

  /// Reference shadow colour constant — black @ ~10%.
  static const Color shadow = Color(0x1A000000);

  /// Scaffold background (dark theme).
  static const Color darkScaffold = Color(0xFF181A20);

  /// Card / sheet / dialog surface (dark theme).
  static const Color darkSurface = Color(0xFF1E1E1E);

  /// Filled input background (light / dark).
  static const Color fieldFill = Color(0xFFF2F4F6);

  /// Pale primary tint used by tag chips and multi-select chips (§10).
  static const Color primaryTint = Color(0xFFFCE7EE);

  /// Gold used by the star rating control.
  static const Color ratingStar = Color(0xFFFFC107);

  /// Retained for backwards compatibility with existing screens.
  static const Color typographyColor = Color(0xFF131927);

  /// Surface used by the search field in dark mode (§6).
  static const Color darkSearchSurface = Color(0xFF2A2A2A);

  /// Popup menu surface in dark mode (§9).
  static const Color darkPopupSurface = Color(0xFF2C2C2E);

  /// Filled input surface (dark) — mirrors mobo_fleet's form-field recipe.
  static final Color inputFillDark = Colors.grey[850]!;

  /// Light brand wash — primary at 8%.
  static const Color primaryWash = Color(0x14C03355);

  /// [primaryWash] laid over white (≈ #FAEFF2) — light-mode fill of the
  /// filter option chips and Active Filters chips. Opaque on purpose: the dark
  /// theme keeps a light canvas, so a translucent chip fill reads as a glowing
  /// box on a dark sheet.
  static final Color primaryTintSolid = Color.alphaBlend(primaryWash, white);

  /// Dark mode, option at rest (unselected chip): neutral grey box.
  static final Color darkOptionFill = Colors.grey[700]!;
  static final Color darkOptionBorder = Colors.grey[600]!;

  /// Dark mode, active (Active Filters chip): deep brand box (≈ #4F242E)
  /// with brand text lightened to stay readable on it (≈ #D66681).
  static final Color darkActiveFill = Color.alphaBlend(
    primaryColor.withValues(alpha: 0.3),
    darkSurface,
  );
  static final Color darkActiveBorder = primaryColor.withValues(alpha: 0.6);
  static final Color darkActiveText = HSLColor.fromColor(
    primaryColor,
  ).withLightness(0.62).toColor();

  /// Inactive submit button fill (light mode). Dark mode keeps grey[700].
  static const Color disabledButtonFill = Color(0xFFBDBDBD);

  /// Label + icon on an inactive submit button, both themes.
  static const Color disabledButtonText = Color(0xFFFFFFFF);

  static Color disabledButtonFillOn(bool isDark) =>
      isDark ? Colors.grey[700]! : disabledButtonFill;

  /// Outline of a field at rest. Light mode needs none — the grey fill stands
  /// out on the white card — but the dark fill is the dark card's own colour,
  /// so there a field would vanish without one.
  static Color restingBorderColor(bool isDark) =>
      isDark ? Colors.grey[700]! : Colors.transparent;

  static BorderSide restingBorderSide(bool isDark) =>
      isDark ? BorderSide(color: restingBorderColor(isDark)) : BorderSide.none;

  /// Brand outline; brand fill + white tick when ticked. Both themes.
  static final CheckboxThemeData checkboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? primaryColor
          : Colors.transparent,
    ),
    checkColor: WidgetStateProperty.all(white),
    side: WidgetStateBorderSide.resolveWith(
      (states) => const BorderSide(color: primaryColor, width: 2),
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  );

  static Color surface(bool isDark) => isDark ? darkSurface : white;
  static Color inputFill(bool isDark) => isDark ? inputFillDark : fieldFill;
  static Color cardBorder(bool isDark) =>
      isDark ? Colors.grey[850]! : Colors.grey[200]!;
  static Color labelColor(bool isDark) => isDark ? Colors.white : dark;
  static Color secondaryLabelColor(bool isDark) =>
      isDark ? Colors.grey[400]! : Colors.grey[600]!;
  static Color hintColor(bool isDark) =>
      isDark ? Colors.grey[400]! : Colors.grey[600]!;
  static Color subtitleColor(bool isDark) =>
      isDark ? Colors.white60 : Colors.black54;
  static Color valueColor(bool isDark) => isDark ? Colors.white : dark;

  /// Primary / secondary text for the active theme, under the names the
  /// shared form-field and select kit (lib/shared/widgets/forms/) uses across
  /// the Mobo apps.
  static Color textPrimaryOn(bool isDark) =>
      isDark ? Colors.white : textPrimary;
  static Color textSecondaryOn(bool isDark) =>
      isDark ? Colors.grey[400]! : textSecondary;

  /// §2/§6 — form-field typography. Both sizes are stated explicitly so a
  /// field doesn't inherit an ambient text theme that differs by screen —
  /// the hint is the same size as the value it stands in for, so the field
  /// doesn't appear to resize as soon as it's filled in (only the weight
  /// changes, w400 → w600). Mirrors mobo_fleet's vehicle-form fields.
  static TextStyle fieldValueStyle(bool isDark) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: isDark ? Colors.white : dark,
  );

  static TextStyle fieldHintStyle(bool isDark) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: isDark ? Colors.white54 : Colors.grey[600],
  );

  /// Vertical rhythm of a form (mobo Billing's create-invoice form): a label
  /// sits [labelGap] above the field it names, and the next label starts
  /// [fieldGap] below that field — the larger gap is what keeps a label
  /// reading as part of its own field rather than the one above it.
  static const double labelGap = 8;
  static const double fieldGap = 16;

  /// The grey label that sits above a field.
  static TextStyle fieldLabelStyle(bool isDark) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: isDark ? Colors.white70 : const Color(0xFF7F7F7F),
  );

  /// A field's own leading/trailing icon — e.g. a dropdown's arrow. A soft
  /// grey in light mode (mobo Billing's create-invoice form), not black,
  /// so it reads as part of the field rather than as bold, high-contrast UI.
  static Color iconColor(bool isDark) =>
      isDark ? Colors.white : Colors.grey[700]!;

  /// `showTimePicker` theming — the hour/minute chips and the AM/PM selector
  /// all use the brand colour for their selected state (Flutter's default
  /// AM/PM tint otherwise falls back to the ambient ColorScheme's
  /// tonal/secondary colour, which reads as a mismatched orange next to the
  /// primary-red hour/minute chips).
  ///
  /// For the hour and minute chips "selected" is the one being edited: it is
  /// brand-filled and the other is grey, so which is under the dial is clear
  /// (a flat brand fill made both look picked). The same state-aware fill
  /// mobo Employee's date-time picker uses.
  static TimePickerThemeData timePickerTheme(bool isDark) {
    final fieldFill = isDark ? Colors.grey[800]! : Colors.grey[100]!;
    Color unselectedText() => isDark ? Colors.white70 : Colors.black87;

    Color hourMinuteBg(Set<WidgetState> states) =>
        states.contains(WidgetState.selected) ? primaryColor : fieldFill;
    Color hourMinuteFg(Set<WidgetState> states) =>
        states.contains(WidgetState.selected) ? Colors.white : unselectedText();
    Color dayPeriodBg(Set<WidgetState> states) =>
        states.contains(WidgetState.selected)
        ? primaryColor
        : Colors.transparent;
    Color dayPeriodFg(Set<WidgetState> states) =>
        states.contains(WidgetState.selected) ? Colors.white : unselectedText();

    return TimePickerThemeData(
      backgroundColor: surface(isDark),
      hourMinuteTextColor: WidgetStateColor.resolveWith(hourMinuteFg),
      hourMinuteColor: WidgetStateColor.resolveWith(hourMinuteBg),
      dialHandColor: primaryColor,
      dialBackgroundColor: primaryColor.withValues(alpha: 0.1),
      dayPeriodColor: WidgetStateColor.resolveWith(dayPeriodBg),
      dayPeriodTextColor: WidgetStateColor.resolveWith(dayPeriodFg),
      dayPeriodBorderSide: BorderSide(
        color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
      ),
    );
  }

  /// The text field a time picker shows once switched to keyboard entry.
  ///
  /// The hour or minute being typed into is always the brand-filled "selected"
  /// one (see [timePickerTheme]), so the default brand-coloured caret vanished
  /// into it and you couldn't tell where you were typing: it is white here, and
  /// a text selection is a pale white wash for the same reason. The drag handle
  /// stays brand — it hangs below the field, on the dialog's own surface.
  ///
  /// Only for the picker's own `Theme`: a white caret anywhere else would be
  /// invisible on a light field.
  static final TextSelectionThemeData timePickerTextSelection =
      TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Colors.white.withValues(alpha: 0.35),
        selectionHandleColor: primaryColor,
      );

  /// Width bounds for every dialog. A bare `Dialog` has no maximum, so on a
  /// phone in landscape (700–900dp wide) one whose content stretches — a
  /// footer of two `Expanded` buttons, say — spans the whole window. 560 is
  /// Material's own maximum; below 640dp wide (any phone in portrait) the
  /// window's margins are the tighter bound and nothing changes.
  static const BoxConstraints dialogConstraints = BoxConstraints(
    minWidth: 280,
    maxWidth: 560,
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: scaffoldBackground,
    dividerColor: divider,
    checkboxTheme: checkboxTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F7FA),
      foregroundColor: dark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    // §3 — flat by convention; depth comes from explicit BoxShadow only.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: primaryColor,
        foregroundColor: white,
        disabledBackgroundColor: disabledButtonFill,
        disabledForegroundColor: disabledButtonText,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    // §9 — app-wide popup menu theme.
    popupMenuTheme: PopupMenuThemeData(
      color: white,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    // §19 — dialogs are fully rounded at radius 20, flat.
    dialogTheme: DialogThemeData(
      backgroundColor: white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      constraints: dialogConstraints,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      // The seeded dark scheme pairs its own light-pink primary with a dark
      // maroon onPrimary; with the brand colour forced in as primary, that
      // maroon would label every filled button and tick every checkbox.
      onPrimary: white,
      secondary: Colors.white.withValues(alpha: 0.10),
    ),
    scaffoldBackgroundColor: darkScaffold,
    checkboxTheme: checkboxTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: primaryColor,
        foregroundColor: white,
        disabledBackgroundColor: Colors.grey[700],
        disabledForegroundColor: disabledButtonText,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: darkPopupSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      constraints: dialogConstraints,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );
}

/// §4 — the spacing / radius scale. `md` (12) is the default when unsure.
class AppRadius {
  /// Small chip corner, tiny inner accents.
  static const double xs = 4;

  /// Compact / status dropdown, icon-button container.
  static const double compact = 5;

  /// Small tab / segment chip.
  static const double chip = 6;

  /// Dropdown / filter control, popup menus, inner input border.
  static const double sm = 8;

  /// Segmented view-selector, quantity / numeric field variant.
  static const double control = 10;

  /// Default radius — cards, list tiles, buttons, text fields, tag chips.
  static const double md = 12;

  /// Kanban column, bottom sheet top corners, panel / section container.
  static const double lg = 16;

  /// Canonical status badge.
  static const double badge = 18;

  /// Pill buttons / chips, dialog theme, pagination counter, filter pill.
  static const double pill = 20;

  /// Tall / full bottom sheet variant (rare).
  static const double sheetTall = 28;
}

class AppSpacing {
  const AppSpacing._();

  /// Bottom padding of a list with a floating button over it:
  /// 56px button + 16px margin + 16px gap.
  static const double fabClearance = 88;
}

/// §3 — the only sanctioned sources of depth. Buttons never carry a shadow.
class AppShadows {
  /// Standard "flat card" shadow — list items, list-style cards, form cards.
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0D000000), // black @ 5%
    offset: Offset(0, 6),
    blurRadius: 16,
    spreadRadius: 2,
  );

  /// "Panel" shadow — bigger surfaces like chart containers, dashboard sections.
  static BoxShadow panelShadow(bool isDark) => BoxShadow(
    color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.08),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  /// Soft shadow for pill-shaped search bars only.
  static const BoxShadow searchShadow = BoxShadow(
    color: Color(0x0A000000), // black @ 4%
    offset: Offset(3, 11),
    blurRadius: 8.5,
    spreadRadius: -3,
  );

  static const List<BoxShadow> card = <BoxShadow>[cardShadow];
  static const List<BoxShadow> search = <BoxShadow>[searchShadow];
  static List<BoxShadow> panel(bool isDark) => <BoxShadow>[panelShadow(isDark)];
}

/// §1 — semantic / status colours. Every status or stage indicator must pull
/// its colour from here instead of inventing a new one.
class StatusColors {
  /// approved, done, posted, won, paid, planned.
  static const Color green = Color(0xFF00A63E);

  /// sent, qualified, in-progress / proposal.
  static const Color blue = Color(0xFF3B82F6);

  /// draft.
  static const Color orange = Color(0xFFF97316);

  /// cancelled, lost.
  static const Color red = Color(0xFFEF4444);

  /// locked / done (secondary "complete" state).
  static const Color teal = Color(0xFF14B8A6);

  /// unknown / default fallback.
  static const Color grey = Color(0xFF6B7280);

  static const Color infoIcon = Color(0xFF60A5FA);
  static Color get infoIconBackground => blue.withValues(alpha: 0.12);
  static const Color infoBackgroundLight = Color(0xFFEFF6FF);
  static const Color infoBackgroundDark = Color(0xFF1E293B);

  static const Color successIcon = Color(0xFF4ADE80);
  static Color get successIconBackground => green.withValues(alpha: 0.12);
  static const Color successBackgroundLight = Color(0xFFECFDF3);
  static const Color successBackgroundDark = Color(0xFF14261B);

  static const Color warningIcon = Color(0xFFFB923C);
  static Color get warningIconBackground => orange.withValues(alpha: 0.12);
  static const Color warningBackgroundLight = Color(0xFFFFF7ED);
  static const Color warningBackgroundDark = Color(0xFF2A1C0E);

  static const Color errorIcon = Color(0xFFF87171);
  static Color get errorIconBackground => red.withValues(alpha: 0.12);
  static const Color errorBackgroundLight = Color(0xFFFEF2F2);
  static const Color errorBackgroundDark = Color(0xFF2A1416);

  /// Maps an Odoo-style state string onto its semantic colour.
  static Color forState(String? state) {
    switch ((state ?? '').toLowerCase().trim()) {
      case 'approved':
      case 'done':
      case 'posted':
      case 'won':
      case 'paid':
      case 'planned':
      case 'confirm':
      case 'confirmed':
      case 'sale':
      case 'open':
      case 'active':
        return green;
      case 'sent':
      case 'qualified':
      case 'proposal':
      case 'in_progress':
      case 'progress':
      case 'assigned':
      case 'ready':
        return blue;
      case 'draft':
      case 'new':
      case 'waiting':
      case 'pending':
        return orange;
      case 'cancel':
      case 'cancelled':
      case 'canceled':
      case 'lost':
      case 'refused':
        return red;
      case 'locked':
      case 'closed':
      case 'finished':
        return teal;
      default:
        return grey;
    }
  }

  /// §10 — the canonical status badge. No border; tinted fill; 11/w600 text.
  /// The status colour shows in both themes, so a state reads the same in
  /// light and dark mode.
  ///
  /// [dropdown] adds a small ⌄ after the label, in the status colour, for a
  /// badge that opens a menu to change the status — without it a tappable
  /// badge looks the same as one that is only a label. Off by default; the
  /// badge's height is the same either way.
  static Widget buildStatusBadge(
    BuildContext context,
    String label, {
    Color? color,
    String? state,
    bool dropdown = false,
  }) {
    final statusColor = color ?? forState(state ?? label);
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: statusColor,
        letterSpacing: 0.1,
      ),
    );
    return Container(
      // A touch less on the arrow's side: the glyph carries its own spacing.
      padding: EdgeInsets.fromLTRB(10, 4, dropdown ? 6 : 10, 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: dropdown
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                text,
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: statusColor,
                ),
              ],
            )
          : text,
    );
  }
}
