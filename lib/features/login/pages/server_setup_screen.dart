import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';
import 'credentials_screen.dart';
import '../../../core/routing/page_transition.dart';
import '../../../core/utils/screen_layout.dart';
import 'login_layout.dart';

class ServerSetupScreen extends StatefulWidget {
  final bool isAddingAccount;

  /// Prefills the server and database, so adding a second account on the
  /// server already in use doesn't mean retyping both.
  final String? initialUrl;
  final String? initialDatabase;

  /// Shown in the error row on arrival — why the user was sent back here.
  final String? initialError;

  const ServerSetupScreen({
    super.key,
    this.isAddingAccount = false,
    this.initialUrl,
    this.initialDatabase,
    this.initialError,
  });

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen>
    with TickerProviderStateMixin {
  /// Animation controllers
  late AnimationController _databaseFadeController;
  late Animation<double> _databaseFadeAnimation;

  /// Control when to show validation messages
  bool _shouldValidate = false;

  /// Track field-level errors
  bool urlHasError = false;
  bool dbHasError = false;

  /// General/inline error shown under fields
  String? inlineError;

  /// Why the user was sent back here (an expired database, say). Kept apart
  /// from [inlineError] because that mirrors the provider's `errorMessage`,
  /// which loading the database list clears — and that load starts on its own
  /// as soon as the last-used server is restored. It goes once the user
  /// changes the server or the database, which is what it was about.
  String? _notice;

  /// How long the URL must be left alone before the server is asked for its
  /// databases.
  static const Duration _urlDebounceDelay = Duration(seconds: 1);

  /// Debounce timer for auto-fetching databases on URL change
  Timer? _urlDebounce;

  /// Suppress auto-fetch while waiting for explicit suggestion selection
  bool _awaitingSuggestionSelection = false;

  @override
  void initState() {
    super.initState();
    _notice = widget.initialError;
    _databaseFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _databaseFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _databaseFadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _urlDebounce?.cancel();
    _databaseFadeController.dispose();
    super.dispose();
  }

  /// Asks the server for its databases once the URL has been left alone for
  /// [_urlDebounceDelay]. Typing, a pasted `http(s)://` URL and a protocol
  /// switch all land here, so they share the one timer — however many of them
  /// one edit sets off, only the last wait runs out and one lookup follows.
  void _scheduleDatabaseFetch(LoginProvider provider) {
    _urlDebounce?.cancel();
    _urlDebounce = Timer(_urlDebounceDelay, () {
      if (!mounted) return;
      if (_awaitingSuggestionSelection) {
        // Wait for suggestion selection before fetching
        return;
      }
      final trimmed = provider.urlController.text.trim();
      if (trimmed.isEmpty || !provider.isValidUrl(trimmed)) return;
      if (dbHasError || inlineError != null) {
        setState(() {
          dbHasError = false;
          inlineError = null;
        });
        provider.formKey.currentState?.validate();
      }
      provider.fetchDatabaseList();
    });
  }

  /// Handle database field animation when databases are fetched
  void _handleDatabaseFetch(LoginProvider provider) {
    if (provider.urlCheck && provider.dropdownItems.isNotEmpty) {
      _databaseFadeController.forward();
    } else if (!provider.urlCheck || provider.dropdownItems.isEmpty) {
      _databaseFadeController.reverse();
    }
  }

  /// Navigate to credentials screen. It hands back a message when it sends
  /// the user here because the database can't be used (it has expired).
  Future<void> _goToCredentials(LoginProvider provider) async {
    final notice = await Navigator.push<String>(
      context,
      dynamicRoute<String>(
        context,
        CredentialsScreen(
          url: provider.getFullUrl(),
          database: provider.database!,
          isAddingAccount: widget.isAddingAccount,
          fromServerSetup: true,
        ),
      ),
    );
    if (!mounted || notice == null) return;
    setState(() => _notice = notice);
  }

  /// Check if user can proceed to credentials
  bool _canProceedToCredentials(LoginProvider provider) {
    return provider.urlController.text.trim().isNotEmpty &&
        provider.database != null &&
        provider.database!.isNotEmpty &&
        !provider.isLoadingDatabases &&
        provider.urlCheck;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = LoginProvider();

        // Set synchronously, right after construction: the provider's own
        // restore of the last-used server stands down once a URL is present.
        if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
          provider.setUrlFromFullUrl(widget.initialUrl!);

          if (widget.initialDatabase != null &&
              widget.initialDatabase!.isNotEmpty) {
            provider.setDatabase(widget.initialDatabase);
            if (provider.isValidUrl(provider.urlController.text)) {
              Future.microtask(() => provider.fetchDatabaseList());
            }
          }
        }
        return provider;
      },
      child: Consumer<LoginProvider>(
        builder: (context, provider, child) {
          _handleDatabaseFetch(provider);

          if (!provider.isLoadingDatabases &&
              provider.errorMessage != inlineError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                inlineError = provider.errorMessage;
              });
            });
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: LoginLayout(
              title: widget.isAddingAccount ? 'Add Account' : 'Sign In',
              subtitle: widget.isAddingAccount
                  ? 'Choose the server for the new account'
                  : 'Configure your server connection',
              // Add Account is pushed over the Profile screen, so it needs a
              // visible way back there; the sign-in flow's first screen has
              // nothing beneath it to return to.
              backButton: widget.isAddingAccount
                  ? LoginBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              child: Form(
                key: provider.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CustomAutocompleteField(
                      controller: provider.urlController,
                      suggestions: provider.previousUrls,
                      enableSuggestions:
                          !provider.isLoadingDatabases &&
                          !(provider.urlCheck &&
                              provider.dropdownItems.isNotEmpty),
                      onSuggestionSelected: (String selection) {
                        provider.setUrlFromFullUrl(selection);

                        // Immediately seed this URL into history so it persists for future launches
                        provider.seedUrlToHistory(selection);

                        final domain = provider.extractDomain(selection);

                        setState(() {
                          urlHasError = domain.isEmpty;
                          _notice = null;

                          // Resume auto-fetching now that user explicitly selected a suggestion
                          _awaitingSuggestionSelection = false;
                        });

                        if (domain.trim().isNotEmpty) {
                          _urlDebounce?.cancel();
                          if (!provider.isLoadingDatabases &&
                              provider.isValidUrl(domain)) {
                            setState(() {
                              dbHasError = false;
                              inlineError = null;
                              _shouldValidate = false;
                            });
                            provider.formKey.currentState?.validate();
                            provider.fetchDatabaseList();
                          }
                        }
                      },
                      child: LoginUrlTextField(
                        controller: provider.urlController,
                        hint: 'Enter Server Address',
                        prefixIcon: Icons.dns,
                        enabled: !provider.disableFields,
                        hasError: urlHasError,
                        selectedProtocol: provider.selectedProtocol,
                        isLoading: provider.isLoadingDatabases,
                        onProtocolAutoDetected: () {
                          provider.clearError();
                          setState(() {
                            _awaitingSuggestionSelection = false;
                            inlineError = null;
                            _notice = null;
                            dbHasError = false;
                            _shouldValidate = false;
                          });
                          _urlDebounce?.cancel();
                          final trimmed = provider.urlController.text.trim();
                          if (trimmed.isNotEmpty &&
                              provider.isValidUrl(trimmed)) {
                            provider.formKey.currentState?.validate();
                            _scheduleDatabaseFetch(provider);
                          }
                        },
                        autovalidateMode: _shouldValidate
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        validator: (value) {
                          if (provider.isLoadingDatabases || !_shouldValidate) {
                            return null;
                          }
                          if (value == null || value.isEmpty) {
                            return 'Server URL is required';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          // Clear the provider's error first: build() copies
                          // `provider.errorMessage` back into [inlineError],
                          // so resetting only the local copy below would
                          // just have the old message restored a frame later.
                          provider.clearError();

                          final newUrlHasError = val.isEmpty;
                          if (urlHasError != newUrlHasError ||
                              dbHasError ||
                              inlineError != null ||
                              _notice != null ||
                              _shouldValidate) {
                            setState(() {
                              urlHasError = newUrlHasError;
                              dbHasError = false;
                              inlineError = null;
                              _notice = null;
                              _shouldValidate = false;
                            });
                            provider.formKey.currentState?.validate();
                          }

                          if (val.trim().isEmpty) {
                            // Nothing to look up — just forget the old
                            // server's databases.
                            _urlDebounce?.cancel();
                            provider.resetDatabaseList();
                          } else {
                            _scheduleDatabaseFetch(provider);
                          }
                        },
                        onProtocolChanged: (protocol) {
                          if (_notice != null) setState(() => _notice = null);
                          provider.setProtocol(protocol);

                          final trimmed = provider.urlController.text.trim();
                          if (trimmed.isNotEmpty &&
                              provider.isValidUrl(trimmed)) {
                            _scheduleDatabaseFetch(provider);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    AnimatedBuilder(
                      animation: _databaseFadeAnimation,
                      builder: (context, child) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _databaseFadeAnimation.value > 0 ? null : 0,
                          child: Opacity(
                            opacity: _databaseFadeAnimation.value,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                (1 - _databaseFadeAnimation.value) * -20,
                              ),
                              child: Column(
                                children: [
                                  LoginDropdownField(
                                    hint: provider.isLoadingDatabases
                                        ? 'Loading...'
                                        : provider.errorMessage != null
                                        ? 'Unable to load'
                                        : 'Database',
                                    value: provider.database,
                                    items:
                                        provider.urlCheck &&
                                            provider.dropdownItems.isNotEmpty
                                        ? provider.dropdownItems
                                        : [],
                                    onChanged:
                                        (provider.disableFields ||
                                            provider.isLoadingDatabases)
                                        ? null
                                        : (val) {
                                            provider.setDatabase(val);
                                            setState(() {
                                              dbHasError =
                                                  (val == null || val.isEmpty);
                                              inlineError = null;
                                              _notice = null;
                                            });
                                            provider.formKey.currentState
                                                ?.validate();
                                          },
                                    validator: (value) {
                                      if (provider.isLoadingDatabases ||
                                          !_shouldValidate) {
                                        return null;
                                      }
                                      if (value == null || value.isEmpty) {
                                        return 'Database is required';
                                      }
                                      return null;
                                    },
                                    hasError: dbHasError,
                                    autovalidateMode: _shouldValidate
                                        ? AutovalidateMode.onUserInteraction
                                        : AutovalidateMode.disabled,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    LoginErrorDisplay(error: inlineError ?? _notice),

                    LoginButton(
                      text: 'Next',
                      onPressed: _canProceedToCredentials(provider)
                          ? () => _goToCredentials(provider)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CustomAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSuggestionSelected;
  final Widget child;
  final bool enableSuggestions;

  const _CustomAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onSuggestionSelected,
    required this.child,
    this.enableSuggestions = true,
  });

  @override
  State<_CustomAutocompleteField> createState() =>
      _CustomAutocompleteFieldState();
}

class _CustomAutocompleteFieldState extends State<_CustomAutocompleteField> {
  bool _showSuggestions = false;
  List<String> _filteredSuggestions = [];
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;

  /// Gap from the field's top edge to the top of the suggestion list.
  static const double _dropdownOffset = 60;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_CustomAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.suggestions != widget.suggestions) {
      if (_focusNode.hasFocus) {
        // Defer updates to after the current frame to avoid modifying the tree during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!widget.enableSuggestions) {
            _hideSuggestions();
            return;
          }
          _updateSuggestions();
          if (_filteredSuggestions.isNotEmpty && _overlayEntry == null) {
            _showSuggestionsOverlay();
          } else if (_overlayEntry != null) {
            // Safely request overlay rebuild after frame
            try {
              _overlayEntry!.markNeedsBuild();
            } catch (_) {}
          }
        });
      }
    }

    if (oldWidget.enableSuggestions && !widget.enableSuggestions) {
      _hideSuggestions();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (!widget.enableSuggestions) return;
      _updateSuggestions();
      if (_filteredSuggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      }
    } else {
      _hideSuggestions();
    }
  }

  void _onTextChanged() {
    if (_focusNode.hasFocus) {
      if (!widget.enableSuggestions) {
        _hideSuggestions();
        return;
      }
      _updateSuggestions();
      if (_overlayEntry != null) {
        if (_showSuggestions && _filteredSuggestions.isNotEmpty) {
          _overlayEntry!.markNeedsBuild();
        } else {
          _removeOverlay();
        }
      }
    }
  }

  void _updateSuggestions() {
    final text = widget.controller.text.toLowerCase().trim();
    if (!widget.enableSuggestions) {
      _filteredSuggestions = [];
      if (!mounted) return;
      setState(() {
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    if (text.isEmpty) {
      _filteredSuggestions = List.from(widget.suggestions);
    } else {
      _filteredSuggestions = widget.suggestions.where((suggestion) {
        final suggestionLower = suggestion.toLowerCase();

        // If user typed a protocol, use startsWith on full string
        if (text.startsWith('http://') || text.startsWith('https://')) {
          return suggestionLower.startsWith(text);
        }

        // Otherwise, compare by domain portion (ignore protocol), startsWith
        final textDomain = _extractDomainFromUrl(text);
        final suggestionDomain = _extractDomainFromUrl(suggestionLower);
        if (suggestionDomain.startsWith(textDomain)) {
          return true;
        }

        // As a fallback, do a contains match on full suggestion
        return suggestionLower.contains(textDomain);
      }).toList();
    }

    if (!mounted) return;
    setState(() {
      _showSuggestions = _filteredSuggestions.isNotEmpty;
    });

    if (_overlayEntry != null) {
      if (_filteredSuggestions.isEmpty) {
        _removeOverlay();
      } else {
        try {
          _overlayEntry!.markNeedsBuild();
        } catch (_) {}
      }
    } else if (_filteredSuggestions.isNotEmpty) {
      _showSuggestionsOverlay();
    }
  }

  String _extractDomainFromUrl(String url) {
    if (url.startsWith('https://')) {
      return url.substring(8);
    } else if (url.startsWith('http://')) {
      return url.substring(7);
    }
    return url;
  }

  void _showSuggestionsOverlay() {
    if (_filteredSuggestions.isEmpty || !widget.enableSuggestions) {
      return;
    }

    if (_overlayEntry != null) {
      return;
    }

    // Get the field's render box to match its width exactly
    final renderBox = context.findRenderObject() as RenderBox?;
    final fieldWidth =
        renderBox?.size.width ?? (MediaQuery.of(context).size.width - 48);

    // The dropdown is white with dark text in both light and dark mode
    const backgroundColor = Colors.white;
    const textColor = Colors.black87;
    final hoverColor = Colors.black.withValues(alpha: 0.05);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final placement = _placeSuggestions(overlayContext);
        if (placement.maxHeight <= 0) return const SizedBox.shrink();

        return Positioned(
          width: fieldWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            followerAnchor: placement.openUp
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            offset: Offset(0, placement.openUp ? -4 : _dropdownOffset),
            child: Material(
              elevation: 4,
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black.withValues(alpha: 0.2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: placement.maxHeight),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: _filteredSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _filteredSuggestions[index];
                      return InkWell(
                        onTap: () {
                          widget.onSuggestionSelected(suggestion);
                          _hideSuggestions();
                          _focusNode.unfocus();
                        },
                        hoverColor: hoverColor,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      final overlayState = Overlay.maybeOf(context);
      if (overlayState != null && overlayState.mounted) {
        overlayState.insert(_overlayEntry!);
      }
    });
  }

  /// Where the suggestion list goes and how tall it may be.
  ///
  /// It always hangs below the field, up to 240dp tall, but never lower than
  /// the top of the on-screen keyboard — the list scrolls inside whatever room
  /// is left. Reading `MediaQuery.of(overlay)` (not this State's context) makes
  /// the overlay rebuild as the keyboard opens and closes. On a phone on its
  /// side the keyboard leaves only ~150dp of the window, and a list hung below
  /// a field sitting low in that sliver would be entirely behind the keyboard —
  /// so it opens upwards instead when there is more room above, and is capped
  /// to the room it opens into.
  ({bool openUp, double maxHeight}) _placeSuggestions(BuildContext overlay) {
    const fullHeight = 240.0;
    final media = MediaQuery.of(overlay);

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) {
      return (openUp: false, maxHeight: fullHeight);
    }

    final fieldTop = box.localToGlobal(Offset.zero).dy;
    final visibleBottom = media.size.height - media.viewInsets.bottom;
    final below = visibleBottom - (fieldTop + _dropdownOffset) - 12;

    if (!(overlay.isLandscape && overlay.isShortScreen)) {
      return (openUp: false, maxHeight: below.clamp(56.0, fullHeight));
    }

    final above = fieldTop - 4 - media.padding.top - 8;

    final openUp = below < 120 && above > below;
    final room = openUp ? above : below;

    // Not even one row fits on either side (a very short sliver above the
    // keyboard): skip the suggestions rather than show a clipped sliver.
    if (room < 56) return (openUp: openUp, maxHeight: 0);
    return (openUp: openUp, maxHeight: math.min(fullHeight, room));
  }

  void _hideSuggestions() {
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(focusNode: _focusNode, child: widget.child),
    );
  }
}
