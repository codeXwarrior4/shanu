import 'package:flutter/material.dart';
import '../widgets/breathing_animation.dart';

class BreathingExerciseScreen extends StatelessWidget {
  const BreathingExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Breathing Exercise")),
      body: const Center(
        child: BreathingAnimation(durationSeconds: 60),
      ),
    );
  }
}