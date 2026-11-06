import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/utils/screen_layout.dart';
import 'login_layout.dart';

/// App lock screen that prompts for biometric authentication
/// Displayed when app is locked and biometric authentication is enabled
class AppLockScreen extends StatefulWidget {
  final VoidCallback? onAuthenticationSuccess;

  const AppLockScreen({super.key, this.onAuthenticationSuccess});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _isAuthenticating = false;
  bool _authenticationFailed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performAuthentication();
    });
  }

  Future<void> _performAuthentication() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final isAvailable = await BiometricService.isBiometricAvailable();
      if (!isAvailable) {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _authenticationFailed = true;
            _errorMessage =
                'Biometric authentication is not available on this device. Please disable biometric lock in settings.';
          });
        }
        return;
      }

      final success = await BiometricService.authenticateWithBiometrics(
        reason: 'Please authenticate to access the Mobo Expenses App',
      );

      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });

        if (success) {
          setState(() {
            _authenticationFailed = false;
            _errorMessage = null;
          });

          widget.onAuthenticationSuccess?.call();
        } else {
          setState(() {
            _authenticationFailed = true;
            _errorMessage =
                'Authentication failed or was cancelled. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _authenticationFailed = true;
          _errorMessage = 'Authentication error: ${e.toString()}';
        });
      }
    }
  }

  /// What the lock is currently doing: waiting, retrying, or the initial hint.
  Widget _buildAuthDisplay() {
    if (_isAuthenticating) return _buildAuthenticatingDisplay();
    if (_authenticationFailed) return _buildRetryButton();
    return _buildInitialDisplay();
  }

  @override
  Widget build(BuildContext context) {
    // On a phone on its side there is no room for a header pinned above the
    // status, so the brand, heading and status scroll together as one page.
    final compact = context.isLandscape && context.isShortScreen;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/loginbg.png'),
                  fit: BoxFit.cover,
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
                    _buildAuthHeader(),
                    const SizedBox(height: 24),
                    _buildAuthDisplay(),
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
                            ),
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
                                    _buildAuthHeader(),
                                    const SizedBox(height: 24),

                                    _buildAuthDisplay(),
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
        ],
      ),
    );
  }

  /// Build app header (Inventory App + logo at top)
  Widget _buildAppHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          "assets/app_logo.png",
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        Text(
          'mobo event',
          style: const TextStyle(
            fontFamily: 'MyFont',
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ],
    );
  }

  /// Build authentication header (centered)
  Widget _buildAuthHeader() {
    return Column(
      children: [
        Text(
          'App Locked',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        Text(
          'Please authenticate to continue',
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

  Widget _buildAuthenticatingDisplay() {
    return Column(
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Authenticating...',
          style: GoogleFonts.manrope(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRetryButton() {
    return Column(
      children: [
        if (_errorMessage != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedAlertCircle,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        SizedBox(
          height: 48,
          width: MediaQuery.of(context).size.width * 0.7,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _authenticationFailed = false;
                _errorMessage = null;
              });
              _performAuthentication();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialDisplay() {
    return Column(
      children: [
        Icon(
          Icons.fingerprint,
          size: 48,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(height: 16),
        Text(
          'Touch sensor or use face unlock',
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
