import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/features/registration/widget/attendee_dailog_box.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';

class ScannerBox extends StatefulWidget {
  final int? id;
  final VoidCallback? onCameraReady;

  /// Fill whatever space the parent gives (square corners, no fixed 300×300)
  /// instead of being a 300×300 rounded box. Landscape uses this for a
  /// full-bleed preview, since a 300dp square plus its hint and button can't
  /// share a ~300dp-tall window.
  final bool expand;

  const ScannerBox({
    super.key,
    this.id,
    this.onCameraReady,
    this.expand = false,
  });

  @override
  State<ScannerBox> createState() => _ScannerBoxState();
}

class _ScannerBoxState extends State<ScannerBox> {
  final controller = MobileScannerController();
  final AudioPlayer _player = AudioPlayer();
  bool _isScanning = false;

  /// A QR that failed stays suppressed while it is still in front of the camera
  /// (so the error shows once, not in a loop) and is forgotten once it has been
  /// out of view for [_forgetAfter]. Any other QR scans immediately.
  String? _failedCode;
  DateTime? _failedLastSeen;
  static const _forgetAfter = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();

    if (widget.onCameraReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCameraReady!();
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = widget.expand
        ? BorderRadius.zero
        : BorderRadius.circular(12);
    return Container(
      height: widget.expand ? null : 300,
      width: widget.expand ? null : 300,
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: MobileScanner(
          controller: controller,
          errorBuilder: (context, exception) {
            // Full-bleed (landscape): keep clear of the hint pill above and
            // the button below, which are overlaid on this.
            return Padding(
              padding: EdgeInsets.symmetric(vertical: widget.expand ? 52 : 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    "assets/scanner_bg.png",
                    height: widget.expand ? 64 : 120,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Camera permission denied",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Please allow camera access to scan",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
          onDetect: (barcodeCapture) async {
            if (_isScanning) return;

            final code = barcodeCapture.barcodes.firstOrNull?.rawValue;

            if (code != null) {
              if (code == _failedCode) {
                final now = DateTime.now();
                final stillInView =
                    now.difference(_failedLastSeen!) < _forgetAfter;
                _failedLastSeen = now;
                if (stillInView) return;
              }

              _isScanning = true;

              await _player.play(AssetSource('beep.mp3'));
              HapticFeedback.vibrate();

              final provider = Provider.of<RegistrationProvider>(
                context,
                listen: false,
              );

              try {
                loadingDialog(
                  context,
                  "Scanning QR",
                  "Please wait while we fetch details",
                  LoadingAnimationWidget.fourRotatingDots(
                    color: primaryColor,
                    size: 30,
                  ),
                );

                if (widget.id != null && widget.id != 0) {
                  await provider.scanQr(code, eventId: widget.id);
                } else {
                  await provider.scanQr(code);
                }

                controller.stop();
                await Future.delayed(const Duration(seconds: 1));

                if (!context.mounted) return;

                hideLoadingDialog(context);

                CustomSnackbar.showSuccess(
                  context,
                  "Fetched details successfully",
                );

                Navigator.pop(context);

                if (provider.scannedAttendee != null) {
                  Future.delayed(const Duration(milliseconds: 200), () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) {
                        return AttendeeDailogBox(
                          attendeeModel: provider.scannedAttendee!,
                        );
                      },
                    );
                  });
                } else {
                  CustomSnackbar.showError(
                    context,
                    "Invalid QR please check your QR and re-scan",
                  );
                }
              } catch (e) {
                _failedCode = code;
                _failedLastSeen = DateTime.now();

                if (!context.mounted) return;

                hideLoadingDialog(context);
                final message = cleanedError(
                  e.toString(),
                ).replaceAll(RegExp(r'[.\s]+$'), '');
                CustomSnackbar.showError(
                  context,
                  "$message. Move the QR away and scan again.",
                );
              } finally {
                _isScanning = false;
              }
            }
          },
        ),
      ),
    );
  }
}
