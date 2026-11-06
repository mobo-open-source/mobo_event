import 'package:flutter/material.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/utils/screen_layout.dart';
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

  /// The "searching" overlay on top of the camera preview: the brand-bordered
  /// frame with the sweeping line, fading out once the camera is ready.
  Widget _searchOverlay(double side) {
    return AnimatedOpacity(
      opacity: showAnimation ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: IgnorePointer(
        child: Container(
          width: side,
          height: side,
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
            builder: (_, _) {
              return Align(
                alignment: Alignment(0, (_scanAnimation.value / 200) * 2 - 1),
                child: Container(height: 1, color: primaryColor),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _selectAttendeeButton() {
    return FilledButton(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
    );
  }

  /// A phone in landscape is ~300–400dp tall, so the portrait stack (a 250dp
  /// preview, the hint, ~35% of the height in spacers, the button) can't fit —
  /// and a live camera preview can't sit inside a scroll view. Instead the
  /// preview fills the window and the hint and button are overlaid on it, one
  /// layer: nothing to scroll and nothing beside the preview. The overlays use
  /// a translucent dark backing so they read over any camera image, in either
  /// theme.
  Widget _buildLandscape() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ScannerBox(id: widget.id, onCameraReady: _onCameraReady, expand: true),
        // Room for the hint above and the button below the searching frame.
        LayoutBuilder(
          builder: (context, constraints) {
            final side = (constraints.maxHeight - 128).clamp(90.0, 300.0);
            return Center(child: _searchOverlay(side));
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code, size: 20, color: Colors.white),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          "Scan your ticket",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                _selectAttendeeButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isLandscape) return _buildLandscape();

    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  _searchOverlay(300),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    Icons.qr_code,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 10),
                const Text("Scan your ticket"),
              ],
            ),

            SizedBox(height: size.height * 0.2),

            _selectAttendeeButton(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
