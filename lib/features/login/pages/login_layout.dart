import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';

class LoginLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? backButton;

  const LoginLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.backButton,
  });

  /// Wraps the form so every field underneath picks up the login look.
  Widget _themedForm(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
          errorStyle: const TextStyle(color: Colors.white),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: StatusColors.red, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A phone on its side has no room for a header pinned above the form, so
    // the header scrolls with the form as one page.
    final compact = context.isLandscape && context.isShortScreen;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                image: DecorationImage(
                  image: AssetImage('assets/images/loginbg.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    isDark
                        ? Colors.black.withValues(alpha: 1)
                        : Colors.white.withValues(alpha: 1),
                    BlendMode.dstATop,
                  ),
                ),
              ),
            ),
          ),

          if (compact)
            Positioned.fill(
              child: LoginCompactBody(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(fit: BoxFit.scaleDown, child: _buildAppHeader()),
                    const SizedBox(height: 16),
                    _buildSignInHeader(),
                    const SizedBox(height: 24),
                    _themedForm(context),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, viewportConstraints) {
                return Column(
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 68),
                        child: _buildAppHeader(),
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              viewportConstraints.maxHeight - 180,
                            ), // Account for header height
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildSignInHeader(),
                                    const SizedBox(height: 40),

                                    _themedForm(context),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          if (backButton != null) backButton!,
        ],
      ),
    );
  }

  /// The calendar in `assets/app_logo.png` fills only the centre 113×113 of
  /// its 273×185 canvas; the rest is transparent margin.
  static const double _logoSize = 32;
  static const double _logoScale = _logoSize / 113;

  /// Build app header (logo + "mobo event" wordmark at top)
  Widget _buildAppHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // "mobo event" has no descenders but YaroRg reserves room for them,
        // so the letters sit ~4px above the centre of the text box; the
        // bottom padding lifts the logo by the same amount.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),

          // Scale the canvas until the calendar alone is [_logoSize] and let
          // the transparent margin spill outside the box, so the gap to the
          // wordmark is the 12px below rather than invisible padding.
          child: SizedBox.square(
            dimension: _logoSize,
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Image.asset(
                "assets/app_logo.png",
                width: 273 * _logoScale,
                height: 185 * _logoScale,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'mobo event',
          style: const TextStyle(
            fontFamily: 'MyFont',
            color: Colors.white,
            fontSize: 28,
          ),
        ),
      ],
    );
  }

  /// Build sign in header (centered)
  Widget _buildSignInHeader() {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        Text(
          subtitle,
          style: GoogleFonts.manrope(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// The round back arrow the auth screens float over their top-left corner.
///
/// A null [onPressed] greys it out, for the stretch where leaving the screen
/// would abandon a request that is still running.
class LoginBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const LoginBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // On its side the corner is where a notch or camera cut-out lives and the
    // status bar eats into the short height, so the button tucks inside the
    // safe area instead of sitting at the portrait offset.
    final compact = context.isLandscape && context.isShortScreen;
    final inset = MediaQuery.paddingOf(context);

    return Positioned(
      top: compact ? inset.top : 24,
      left: compact ? inset.left : 0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            height: 64,
            width: 64,
            alignment: Alignment.center,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: onPressed == null ? Colors.white54 : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// The landscape body the auth screens share: ONE page that scrolls as a
/// whole, with everything stacked in a single column.
///
/// A phone on its side is only ~300–400dp tall, too short to pin a header
/// above the form. Here the header is part of the same scroll as the form, so
/// with the keyboard up the page scrolls to the focused field and to the
/// button. The column is centred and capped to a readable width, sits inside
/// the safe area so nothing hides behind a notch, and is vertically centred
/// when it happens to fit.
class LoginCompactBody extends StatelessWidget {
  final Widget child;

  const LoginCompactBody({super.key, required this.child});

  static const _padding = EdgeInsets.fromLTRB(24, 12, 24, 16);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: _padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight - _padding.vertical,
                ),
              ),
              child: ConstrainedContent(
                maxWidth: 400,
                alignment: Alignment.center,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Common text field builder for login screens
class LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Widget prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final List<String>? autofillHints;

  const LoginTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.suffixIcon,
    this.hasError = false,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autofillHints: autofillHints,
      cursorColor: Colors.black,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black.withValues(alpha: .4),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: prefixIcon,
        ),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? Colors.black26
              : Colors.black54,
        ),
        suffixIcon: hasError
            ? Icon(Icons.error_outline, color: StatusColors.red, size: 20)
            : suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }
}

/// Common dropdown field builder for login screens
class LoginDropdownField extends StatefulWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?)? onChanged;
  final String? Function(String?)? validator;
  final bool hasError;
  final AutovalidateMode? autovalidateMode;

  const LoginDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.validator,
    this.hasError = false,
    this.autovalidateMode,
  });

  @override
  State<LoginDropdownField> createState() => _LoginDropdownFieldState();
}

class _LoginDropdownFieldState extends State<LoginDropdownField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _handleMenuOpen(BuildContext context) async {
    FocusScope.of(context).unfocus();

    // Wait for keyboard to close, then open dropdown
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    _showDropdownOverlay();
  }

  void _showDropdownOverlay() {
    final uniqueItems = widget.items.toSet().toList();
    if (uniqueItems.isEmpty) return;
    if (_overlayEntry != null) return; // already open

    final renderBox = context.findRenderObject() as RenderBox?;
    final fieldWidth =
        renderBox?.size.width ?? (MediaQuery.of(context).size.width - 48);

    // Calculate dynamic height so the dropdown doesn't hit the bottom of the screen
    final fieldOffset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final screenHeight = MediaQuery.of(context).size.height;
    final fieldHeight = renderBox?.size.height ?? 0;
    final availableBelow = screenHeight - (fieldOffset.dy + fieldHeight) - 16; // keep 16px margin

    // Limit visible items to 5 rows (others scroll)
    const double itemHeight = 44.0; // consistent row height
    const double listVerticalPadding = 16.0; // 8 top + 8 bottom
    final double heightForFiveItems = itemHeight * 5 + listVerticalPadding;
    double maxDropdownHeight = math.max(
      120.0, // minimum sensible height (~2 items)
      math.min(availableBelow, heightForFiveItems),
    );

    // On a phone on its side the field often sits low in the window, with
    // less room under it than the list needs. Portrait keeps the list below
    // the field; here it opens upwards when that side has more room, and is
    // capped to the room it opens into so it never runs off the window.
    var openUp = false;
    if (context.isLandscape && context.isShortScreen) {
      final media = MediaQuery.of(context);
      final below =
          screenHeight -
          media.viewInsets.bottom -
          (fieldOffset.dy + fieldHeight) -
          16;
      final above = fieldOffset.dy - media.padding.top - 16;
      openUp = below < heightForFiveItems && above > below;
      maxDropdownHeight = math.max(
        64.0,
        math.min(openUp ? above : below, heightForFiveItems),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          // Tap outside to dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideDropdown,
            ),
          ),
          Positioned(
            width: fieldWidth,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              followerAnchor: openUp ? Alignment.bottomLeft : Alignment.topLeft,
              offset: Offset(0, openUp ? -4 : 58),
              child: Material(
                elevation: 4,
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                shadowColor: Colors.black.withValues(alpha: 0.2),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxDropdownHeight),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemExtent: itemHeight,
                      itemCount: uniqueItems.length,
                      itemBuilder: (context, index) {
                        final item = uniqueItems[index];
                        return InkWell(
                          onTap: () {
                            widget.onChanged?.call(item);
                            _hideDropdown();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Text(
                              item,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Insert into overlay layer after build frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      final overlayState = Overlay.maybeOf(context);
      if (overlayState != null && overlayState.mounted) {
        overlayState.insert(_overlayEntry!);
      }
    });
  }

  void _hideDropdown() {
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final uniqueItems = widget.items.toSet().toList();
    final safeValue = uniqueItems.contains(widget.value) ? widget.value : null;
    final bool isEnabled = widget.onChanged != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: FormField<String>(
        initialValue: safeValue,
        validator: widget.validator,
        autovalidateMode: widget.autovalidateMode,
        builder: (field) {
          // Keep the FormField's internal value in sync with the external widget.value
          final externalValue = uniqueItems.contains(widget.value)
              ? widget.value
              : null;
          if (field.value != externalValue) {
            // Schedule the change after build to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              field.didChange(externalValue);
            });
          }

          // Always use the external (provider-backed) value for display
          final effectiveValue = externalValue;
          final showErrorIcon =
              widget.hasError &&
              (effectiveValue == null || effectiveValue.isEmpty);

          return Builder(
            builder: (rowCtx) {
              return InkWell(
                onTap: () => _handleMenuOpen(rowCtx),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  isEmpty: (effectiveValue == null || effectiveValue.isEmpty),
                  decoration: InputDecoration(
                    enabled: isEnabled,
                    prefixIcon: Icon(Icons.storage, size: 20),
                    prefixIconColor: WidgetStateColor.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? Colors.black26
                          : Colors.black54,
                    ),
                    suffixIcon: showErrorIcon
                        ? Icon(Icons.error, color: StatusColors.red, size: 20)
                        : InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (_overlayEntry == null) {
                                _handleMenuOpen(rowCtx);
                              } else {
                                _hideDropdown();
                              }
                            },
                            child: Icon(
                              _overlayEntry == null
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              size: 20,
                              color: isEnabled
                                  ? Colors.black54
                                  : Colors.black26,
                            ),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    errorText: field.errorText,
                    errorStyle: const TextStyle(color: Colors.white),
                  ),
                  child: Text(
                    effectiveValue ?? widget.hint,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: (effectiveValue == null || effectiveValue.isEmpty)
                          ? Colors.black.withValues(alpha: .4)
                          : Colors.black,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Common error display widget
class LoginErrorDisplay extends StatelessWidget {
  final String? error;

  const LoginErrorDisplay({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    // At least 40 — what a one- or two-line message needs — but free to grow,
    // so a longer one (the expired-database notice runs to three lines on a
    // narrow phone) pushes what follows down instead of overflowing.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: error != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// URL text field with integrated protocol dropdown
class LoginUrlTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final bool autofocus;
  final String selectedProtocol;
  final ValueChanged<String>? onProtocolChanged;
  final bool isLoading;

  /// Notifies parent when user typed/pasted a full URL with protocol (http/https)
  final VoidCallback? onProtocolAutoDetected;

  const LoginUrlTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.hasError = false,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
    this.autofocus = false,
    this.selectedProtocol = 'https://',
    this.onProtocolChanged,
    this.isLoading = false,
    this.onProtocolAutoDetected,
  });

  @override
  State<LoginUrlTextField> createState() => _LoginUrlTextFieldState();
}

class _LoginUrlTextFieldState extends State<LoginUrlTextField> {
  bool _isAdjustingText = false;

  @override
  void initState() {
    super.initState();

    // Listen for user typing/pasting a full URL including protocol
    widget.controller.addListener(_handleTypedProtocolInField);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTypedProtocolInField);
    super.dispose();
  }

  void _handleTypedProtocolInField() {
    if (_isAdjustingText) return;
    final raw = widget.controller.text;
    final text = raw.trim();
    if (text.isEmpty) return;

    String? detectedProtocol;
    String domain = text;

    if (text.startsWith('http://')) {
      detectedProtocol = 'http://';
      domain = text.substring(7);
    } else if (text.startsWith('https://')) {
      detectedProtocol = 'https://';
      domain = text.substring(8);
    }

    if (detectedProtocol != null) {
      widget.onProtocolAutoDetected?.call();
      _isAdjustingText = true;
      try {
        if (widget.onProtocolChanged != null &&
            widget.selectedProtocol != detectedProtocol) {
          widget.onProtocolChanged!(detectedProtocol);
        }

        // Strip protocol from the text field so only domain/host remains
        if (domain != raw) {
          widget.controller
            ..text = domain
            ..selection = TextSelection.collapsed(offset: domain.length);

          widget.onChanged?.call(domain);
        }
      } finally {
        _isAdjustingText = false;
      }
    }
  }

  Future<void> _handleProtocolMenuOpen(BuildContext context) async {
    FocusScope.of(context).unfocus();

    // Wait for keyboard to close, then open dropdown
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    _openProtocolMenu(context);
  }

  Future<void> _openProtocolMenu(BuildContext context) async {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size size = button.size;

    final selected = await showMenu<String>(
      context: context,
      color: Colors.white,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(offset.dx, offset.dy + size.height, size.width, 0),
        Offset.zero & overlay.size,
      ),
      constraints: BoxConstraints(minWidth: size.width, maxWidth: size.width),
      items: ['http://', 'https://']
          .map(
            (p) => PopupMenuItem<String>(
              value: p,
              child: Text(
                p,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selected != null && mounted) {
      widget.onProtocolChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      cursorColor: Colors.black,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black.withValues(alpha: .4),
        ),
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                widget.prefixIcon,
                size: 20,
                color: widget.enabled ? Colors.black54 : Colors.black26,
              ),
            ),

            Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Colors.black.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Builder(
                builder: (ctx) {
                  return InkWell(
                    onTap: () => _handleProtocolMenuOpen(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.selectedProtocol,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.enabled
                                  ? Colors.black
                                  : Colors.black26,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: widget.enabled
                                ? Colors.black54
                                : Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.hasError
            ? Icon(Icons.error_outline, color: StatusColors.red, size: 20)
            : widget.isLoading
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                  ),
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.only(
          left: 0,
          right: 20,
          top: 16,
          bottom: 16,
        ),
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? loadingWidget;

  const LoginButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withValues(alpha: .2),
          disabledForegroundColor: Colors.white,
          overlayColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading && loadingWidget != null
            ? loadingWidget!
            : Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
