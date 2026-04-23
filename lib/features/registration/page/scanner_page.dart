import 'package:flutter/material.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/registration/page/attendees_page.dart';
import 'package:mobo_event/features/registration/page/event_attendees_page.dart';
import '../widget/scanner_box.dart';

class ScannerUI extends StatefulWidget {
  final int id;
  const ScannerUI({super.key, required this.id});

  @override
  State<ScannerUI> createState() => _ScannerUIState();
}

class _ScannerUIState extends State<ScannerUI>
    with SingleTickerProviderStateMixin {
  bool showAnimation = true;
  bool cameraReady = false;
  bool minTimePassed = false;

  late AnimationController _controller;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(
      begin: 0,
      end: 200,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(const Duration(seconds: 1), () {
      minTimePassed = true;
      _tryHideAnimation();
    });
  }

  void _onCameraReady() {
    cameraReady = true;
    _tryHideAnimation();
  }

  void _tryHideAnimation() {
    if (cameraReady && minTimePassed && mounted) {
      setState(() {
        showAnimation = false;
      });
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: size.height * 0.1),

            SizedBox(
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ScannerBox(id: widget.id, onCameraReady: _onCameraReady),

                  AnimatedOpacity(
                    opacity: showAnimation ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    child: IgnorePointer(
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          image: const DecorationImage(
                            image: AssetImage('assets/scanner_bg.png'),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: primaryColor, width: 1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: AnimatedBuilder(
                          animation: _scanAnimation,
                          builder: (_, __) {
                            return Align(
                              alignment: Alignment(
                                0,
                                (_scanAnimation.value / 200) * 2 - 1,
                              ),
                              child: Container(height: 1, color: primaryColor),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  child: Icon(Icons.qr_code, color: Colors.black),
                ),
                const SizedBox(width: 10),
                const Text("Scan your ticket"),
              ],
            ),

            SizedBox(height: size.height * 0.2),

            FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onPressed: () {
                if (widget.id == 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => AttendeesPage()),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventAttendeesPage(eventId: widget.id),
                    ),
                  );
                }
              },
              child: const Text("Select Attendee"),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
