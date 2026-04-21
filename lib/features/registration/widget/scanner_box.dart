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
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';

class ScannerBox extends StatefulWidget {
  final int? id;
  final VoidCallback? onCameraReady;

  const ScannerBox({super.key, this.id, this.onCameraReady});

  @override
  State<ScannerBox> createState() => _ScannerBoxState();
}

class _ScannerBoxState extends State<ScannerBox> {
  final controller = MobileScannerController();
  final AudioPlayer _player = AudioPlayer();
  bool _isScanning = false;

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
    return Container(
      height: 300,
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MobileScanner(
          controller: controller,
          errorBuilder: (context, exception) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/scanner_bg.png", height: 120),
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
            );
          },
          onDetect: (barcodeCapture) async {
            if (_isScanning) return;

            final code = barcodeCapture.barcodes.first.rawValue;

            if (code != null) {
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
                if (!context.mounted) return;

                hideLoadingDialog(context);
                CustomSnackbar.showError(context, cleanedError(e.toString()));
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
