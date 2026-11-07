import 'package:flutter/material.dart';
import 'package:mobo_event/app/app_entry.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_event/core/utils/screen_layout.dart';
import 'package:mobo_event/features/onboarding/get_started_screen.dart';

/// The flat colour behind the splash video's logo, sampled from its frames.
/// Used as the window colour when the portrait video is letterboxed, so the
/// bars on either side read as part of the picture.
const Color _splashVideoBackground = Color(0xFFB02254);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller =
        VideoPlayerController.asset('assets/splash/mobo_event_splash.mp4')
          ..initialize().then((_) {
            setState(() {});
            _controller.play();
          });

    _controller.addListener(() {
      if (_controller.value.isInitialized &&
          _controller.value.position >= _controller.value.duration &&
          !_controller.value.isPlaying &&
          !_navigated) {
        _navigated = true;
        _goNext();
      }
    });
  }

  Future<void> _goNext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('hasSeenGetStarted') ?? false;
      if (!mounted) return;

      if (!hasSeen) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const GetStartedScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AppEntry()),
          (route) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AppEntry()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The video is a tall portrait clip. Filling a landscape window with it
    // would crop it to a thin horizontal slice and cut the logo in half, so
    // there it is shown whole and centred over its own background colour.
    final landscape = context.isLandscape;

    return Scaffold(
      backgroundColor: landscape ? _splashVideoBackground : Colors.black,
      body: SizedBox.expand(
        child: FittedBox(
          fit: landscape ? BoxFit.contain : BoxFit.cover,
          child: SizedBox(
            width: _controller.value.isInitialized
                ? _controller.value.size.width
                : 1,
            height: _controller.value.isInitialized
                ? _controller.value.size.height
                : 1,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
