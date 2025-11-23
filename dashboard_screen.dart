// lib/screens/dashboard_screen.dart
import 'dart:async';
//import 'package:aayu_track/breathing_exercise_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'breathing_exercise_screen.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/streak_badge.dart';
import '../theme.dart';
import '../localization.dart'; // localization helper

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final Box _box;
  final FlutterTts _tts = FlutterTts();
  bool _loading = true;

  Map<String, dynamic> profile = {};
  List<Map<String, dynamic>> _medLogs = [];
  int _streakMedication = 0;
  int _streakSteps = 0;
  int _streakHydration = 0;

  int _steps = 2500;
  int _heartRate = 78;
  int _hydration = 1300;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    // Ensure the box is opened in main; here we just read it
    _box = Hive.box('aayutrack_box');
    await NotificationService.init();
    await _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _tts.stop();
    super.dispose();
  }

  /// Convenience translator + parameter replacer
  /// Usage: tr(context, 'reminderMessage', {'name': 'Saurabh'});
  String tr(BuildContext ctx, String key, [Map<String, String>? params]) {
    final loc = AppLocalizations.of(ctx);
    String s = loc?.t(key) ?? key;
    if (params != null && params.isNotEmpty) {
      params.forEach((k, v) {
        s = s.replaceAll('{$k}', v);
      });
    }
    return s;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 120));
    profile = Map<String, dynamic>.from(_box.get('profile', defaultValue: {}));
    final rawLogs = List<Map<dynamic, dynamic>>.from(
      _box.get('med_logs', defaultValue: []),
    );
    _medLogs = rawLogs.map((e) => Map<String, dynamic>.from(e)).toList();

    _streakMedication = (_box.get('streak_med', defaultValue: 0) as int);
    _streakSteps = (_box.get('streak_steps', defaultValue: 0) as int);
    _streakHydration = (_box.get('streak_hydration', defaultValue: 0) as int);

    _animController.forward();
    setState(() => _loading = false);
  }

  Future<void> _remindNow() async {
    final name = profile['name'] ?? tr(context, 'user');
    final msg = tr(context, 'reminderMessage', {'name': name});

    try {
      // try to set TTS language to current locale if possible
      final langCode = Localizations.localeOf(context).languageCode;
      // map simple codes to TTS locales; fallback to 'en-IN'
      final ttsLang = switch (langCode) {
        'hi' => 'hi-IN',
        'mr' => 'mr-IN',
        'kn' => 'kn-IN',
        _ => 'en-IN',
      };
      await _tts.setLanguage(ttsLang);
      await _tts.setSpeechRate(0.9);
      await _tts.speak(msg);
      await NotificationService.showInstant(
        title: tr(context, 'notifReminderTitle'),
        body: msg,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'voiceReminderSent'))),
        );
      }
    } catch (e) {
      debugPrint('Reminder error: $e');
    }
  }

  Future<void> _generateQuickReport() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      final name = profile['name'] ?? tr(context, 'user');
      final date = DateFormat.yMMMd().add_jm().format(DateTime.now());
      final localeCode = Localizations.localeOf(context).languageCode;

      await PdfService.generateCheckupReport(
        patientName: name,
        dateTime: date,
        symptom: tr(context, 'reportSymptom'),
        diagnosis:
            "${tr(context, 'steps')}: $_steps • ${tr(context, 'heartRate')}: $_heartRate bpm • ${tr(context, 'water')}: $_hydration ml\n\n${tr(context, 'stayConsistent')}",
        lang: localeCode,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'pdfGenerated'))),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr(context, 'reportFailed')}: $e')));
      }
    }
  }

  Future<void> _markSteps(int amount) async {
    final todayKey = 'last_steps_date';
    final last = _box.get(todayKey);
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    if (last != todayStr && amount >= 1000) {
      _streakSteps++;
      await _box.put('streak_steps', _streakSteps);
      await _box.put(todayKey, todayStr);
    }
    _steps += amount;
    await _loadData();
  }

  Future<void> _markHydration(int amountMl) async {
    final todayKey = 'last_hydration_date';
    final last = _box.get(todayKey);
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    if (last != todayStr && amountMl >= 200) {
      _streakHydration++;
      await _box.put('streak_hydration', _streakHydration);
      await _box.put(todayKey, todayStr);
    }
    _hydration += amountMl;
    await _loadData();
  }

  Future<void> _toggleMed(Map<String, dynamic> m, bool value) async {
    m['taken'] = value;
    final logs = List<Map<dynamic, dynamic>>.from(
        _box.get('med_logs', defaultValue: []));
    final idx = logs.indexWhere((e) => e['id'] == m['id']);
    if (idx >= 0) {
      logs[idx] = m;
    } else {
      logs.add(m);
    }
    await _box.put('med_logs', logs);
    await _loadData();
  }

  Widget _buildHeader() {
    final name = profile['name'] ?? tr(context, 'welcome');
    return Row(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.local_hospital, color: kTeal, size: 38),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, 'hello'),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                tr(context, 'tagline'),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_note),
          onPressed: () => Navigator.pushNamed(context, '/profile'),
        ),
      ],
    );
  }

  /// Responsive stats row:
  /// - On narrow screens: horizontal scrollable row
  /// - On normal/wide: three cards expanded in a row
  Widget _buildStats() {
    const double statsHeight = 120;

    final stats = [
      _StatBox(
        child: StatCard(
          title: tr(context, 'steps'),
          value: '$_steps',
          icon: Icons.directions_walk,
        ),
      ),
      _StatBox(
        child: StatCard(
          title: tr(context, 'heartRate'),
          value: '$_heartRate bpm',
          icon: Icons.favorite,
        ),
      ),
      _StatBox(
        child: StatCard(
          title: tr(context, 'hydration'),
          value: '$_hydration ml',
          icon: Icons.local_drink,
        ),
      ),
    ];

    return FadeTransition(
      opacity:
          CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
      child: LayoutBuilder(builder: (ctx, constraints) {
        // if screen is narrow (e.g. phones with small width) -> use horizontal scroll
        if (constraints.maxWidth < 380) {
          return SizedBox(
            height: statsHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stats.length,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                return SizedBox(
                  width: (constraints.maxWidth * 0.7).clamp(110.0, 220.0),
                  child: stats[i],
                );
              },
            ),
          );
        }

        // normal/wider screens: show three in a row with equal width
        return SizedBox(
          height: statsHeight,
          child: Row(
            children: [
              Expanded(child: stats[0]),
              const SizedBox(width: 12),
              Expanded(child: stats[1]),
              const SizedBox(width: 12),
              Expanded(child: stats[2]),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMedications() {
    final meds = _medLogs.reversed.take(4).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, color: kTeal),
                const SizedBox(width: 8),
                Text(tr(context, 'medication'),
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/reminders'),
                  icon: const Icon(Icons.schedule),
                  label: Text(tr(context, 'manage')),
                ),
              ],
            ),
            const Divider(),
            if (meds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(tr(context, 'noMedicines')),
              )
            else
              ...meds.map(
                (m) => ListTile(
                  dense: true,
                  title: Text(m['name'] ?? tr(context, 'medicine')),
                  subtitle: Text("${tr(context, 'at')} ${m['time'] ?? '--'}"),
                  trailing: Checkbox(
                    value: m['taken'] == true,
                    onChanged: (v) => _toggleMed(m, v ?? false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.notifications_active),
            label: Text(tr(context, 'remindNow')),
            onPressed: _remindNow,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(tr(context, 'exportReport')),
            onPressed: _generateQuickReport,
          ),
        ),
      ],
    );
  }

  Widget _buildBreathingCard() {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: Icon(Icons.self_improvement, color: kTeal, size: 32),
      title: Text(
        AppLocalizations.of(context)!.breathingExercise,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(AppLocalizations.of(context)!.breathingTapToStart),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BreathingExerciseScreen()),
        );
      },
    ),
  );
}

  Widget _buildHealthTips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          tr(context, 'healthTips'),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildStats(),
          const SizedBox(height: 14),
          // Streak Cards
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${tr(context, 'medStreak')}\n$_streakMedication ${tr(context, 'days')}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/reminders'),
                    child: Text(tr(context, 'view')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${tr(context, 'stepsStreak')}\n$_streakSteps ${tr(context, 'days')}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _markSteps(1000),
                    child: Text(tr(context, 'addSteps')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${tr(context, 'hydrationStreak')}\n$_streakHydration ${tr(context, 'days')}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _markHydration(250),
                    child: Text(tr(context, 'addWater')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildMedications(),
          const SizedBox(height: 14),
          _buildActions(),
          _buildBreathingCard(),
          const SizedBox(height: 14),

          _buildHealthTips(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final Widget child;
  const _StatBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: child,
    );
  }
}
