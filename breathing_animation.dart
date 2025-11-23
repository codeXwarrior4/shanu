import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class BreathingAnimation extends StatefulWidget {
  final int durationSeconds;

  const BreathingAnimation({super.key, this.durationSeconds = 60});

  @override
  State<BreathingAnimation> createState() => _BreathingAnimationState();
}

class _BreathingAnimationState extends State<BreathingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? timer;

  int remaining = 0;
  bool isRunning = false;
  bool isCompleted = false;
  String phase = "Tap to start";

  @override
  void initState() {
    super.initState();
    remaining = widget.durationSeconds;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(_syncVibration);
  }

  // ---------------------- VIBRATION SYNC ----------------------
  Future<void> _syncVibration() async {
    if (!isRunning) return;

    bool supported = await Vibration.hasCustomVibrationsSupport() ?? false;
    if (!supported) return;

    double v = _controller.value;

    if (_controller.status == AnimationStatus.forward) {
      Vibration.vibrate(duration: 35, amplitude: (80 + v * 175).toInt());
    } else {
      Vibration.vibrate(duration: 35, amplitude: (255 - v * 175).toInt());
    }
  }

  // ---------------------- START EXERCISE ----------------------
  void start() {
    setState(() {
      isRunning = true;
      isCompleted = false;
      phase = "Inhale";
      remaining = widget.durationSeconds;
    });

    _controller.repeat(reverse: true);

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      setState(() => remaining--);

      phase = _controller.status == AnimationStatus.forward
          ? "Inhale"
          : "Exhale";

      if (remaining <= 0) finishExercise();
    });
  }

  // ---------------------- FINISH EXERCISE ----------------------
  void finishExercise() {
    timer?.cancel();
    _controller.stop();

    setState(() {
      isRunning = false;
      isCompleted = true;
      phase = "Great Job! 🎉";
    });
  }

  // ---------------------- RESTART EXERCISE ----------------------
  void restart() {
    setState(() {
      isCompleted = false;
      phase = "Tap to start";
      remaining = widget.durationSeconds;
    });
  }

  // ---------------------- STOP ----------------------
  void stop() {
    timer?.cancel();
    _controller.stop();

    setState(() {
      isRunning = false;
      phase = "Tap to start";
      remaining = widget.durationSeconds;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(
          painter: SmartBreathingPainter(animation: _controller),
          child: const SizedBox(width: 240, height: 240),
        ),

        const SizedBox(height: 20),

        Text(
          phase,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        if (!isCompleted)
          Text(
            "$remaining s",
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),

        const SizedBox(height: 20),

        if (isCompleted)
          ElevatedButton(
            onPressed: restart,
            child: const Text("Restart"),
          )
        else
          ElevatedButton(
            onPressed: isRunning ? stop : start,
            child: Text(isRunning ? "Stop" : "Start"),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------
//              BREATHING CIRCLE PAINTER (Perfect Spacing)
// --------------------------------------------------------------------
class SmartBreathingPainter extends CustomPainter {
  final Animation<double> animation;

  SmartBreathingPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    double scale = 0.7 + (animation.value * 0.5);

    final Paint paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    const int rings = 5;
    const int baseDots = 10;

    double maxRadius = (size.width / 2) * scale;
    double ringSpacing = maxRadius / (rings + 1);

    for (int r = 0; r < rings; r++) {
      double ringRadius = ringSpacing * (r + 1);
      int dots = baseDots + (r * 6);
      double dotSize = 3 + (r * 1.4);

      for (int i = 0; i < dots; i++) {
        double angle = (2 * pi / dots) * i;

        Offset pos = Offset(
          center.dx + ringRadius * cos(angle),
          center.dy + ringRadius * sin(angle),
        );

        canvas.drawCircle(pos, dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}