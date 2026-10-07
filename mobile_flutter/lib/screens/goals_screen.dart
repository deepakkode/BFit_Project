import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_controller.dart';
import '../core/models.dart';
import '../core/palette.dart';
import '../core/wellness_metrics.dart';
import '../core/widgets.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _dailySteps = TextEditingController();
  final _weeklyRuns = TextEditingController();
  final _monthlyDistance = TextEditingController();
  GoalRecommendation? _recommendation;
  bool _goalsLoaded = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _historyError;
  String? _savedMessage;
  int _seenProfileRevision = 0;

  @override
  void initState() {
    super.initState();
    _seenProfileRevision = widget.controller.profileRevision;
    _load();
  }

  @override
  void didUpdateWidget(GoalsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final revision = widget.controller.profileRevision;
    if (revision != _seenProfileRevision) {
      _seenProfileRevision = revision;
      _load();
    }
  }

  @override
  void dispose() {
    _dailySteps.dispose();
    _weeklyRuns.dispose();
    _monthlyDistance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
      _historyError = null;
    });
    try {
      final goals = await widget.controller.api.goals();
      _dailySteps.text = '${goals.dailySteps}';
      _weeklyRuns.text = '${goals.weeklyRuns}';
      _monthlyDistance.text = _formatDistance(goals.monthlyDistance);
      _goalsLoaded = true;
    } on ApiException catch (error) {
      _error = error.message;
    }
    try {
      final history = await widget.controller.api.stepHistory();
      _recommendation = recommendStepGoal(
        history,
        DateTime.now().toUtc(),
        widget.controller.user,
      );
      _historyError = null;
    } on ApiException catch (error) {
      _historyError = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final daily = int.tryParse(_dailySteps.text);
    final weekly = int.tryParse(_weeklyRuns.text);
    final monthly = double.tryParse(_monthlyDistance.text);
    if (daily == null || daily < 1 || daily > 100000 ||
        weekly == null || weekly < 0 || weekly > 100 ||
        monthly == null || monthly < 0 || monthly > 10000) {
      setState(() => _error = 'Check your goals. Daily steps must be 1–100,000; runs 0–100; distance 0–10,000 km.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _savedMessage = null;
    });
    try {
      final result = await widget.controller.saveGoals(GoalSettings(
        dailySteps: daily,
        weeklyRuns: weekly,
        monthlyDistance: monthly,
      ));
      _dailySteps.text = '${result.dailySteps}';
      _weeklyRuns.text = '${result.weeklyRuns}';
      _monthlyDistance.text = _formatDistance(result.monthlyDistance);
      _savedMessage = 'Your goals are saved.';
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applySuggestion() {
    if (_recommendation == null) return;
    setState(() {
      _dailySteps.text = '${_recommendation!.dailyStepGoal}';
      _savedMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = _recommendation;
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(21, 20, 21, 30),
            children: [
              const Eyebrow('AIM FOR WHAT FEELS RIGHT'),
              const SizedBox(height: 7),
              Text('Goals with room to grow.', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Set intentions that fit your life, not someone else’s.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 23),
              if (_loading && !_goalsLoaded)
                const SurfacePanel(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_goalsLoaded) ...[
                if (recommendation != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: palette.forest,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_outlined, color: palette.citrus, size: 19),
                          const SizedBox(width: 8),
                          const Eyebrow('A GRADUAL SUGGESTION', color: Color(0xFFCBDBD0)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCount(recommendation.dailyStepGoal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 37,
                              height: 1.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('steps / day', style: TextStyle(color: Color(0xFFCBDBD0))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        recommendation.isPersonalized
                            ? 'Based on your ${recommendation.sampleDays} tracked days and a gradual step up from your ${_formatCount(recommendation.averageSteps)}-step average.'
                            : 'An optional suggestion using your recent steps and, when provided, your age, height, weight and gender. After three tracked days, BFit can make it more personal.',
                        style: const TextStyle(color: Color(0xFFE0EAE3), height: 1.45, fontSize: 13),
                      ),
                      const SizedBox(height: 15),
                      OutlinedButton(
                        onPressed: _applySuggestion,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.citrus,
                          side: BorderSide(color: palette.citrus.withOpacity(0.7)),
                        ),
                        child: const Text('Use this suggestion'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ] else ...[
                  SurfacePanel(
                    padding: const EdgeInsets.all(16),
                    color: palette.surfaceRaised,
                    child: Text(
                      _historyError == null
                          ? 'A step-goal suggestion will appear when your recent history is available.'
                          : 'Your saved goal is available, but recent steps could not load for a personal suggestion.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.ink),
                    ),
                  ),
                  const SizedBox(height: 19),
                ],
                const SectionTitle('Your intentions'),
                const SizedBox(height: 12),
                SurfacePanel(
                  padding: const EdgeInsets.fromLTRB(17, 17, 17, 17),
                  child: Column(
                    children: [
                      _GoalRow(
                        icon: Icons.directions_walk_rounded,
                        label: 'Daily steps',
                        helper: 'Your everyday movement',
                        controller: _dailySteps,
                        suffix: 'steps',
                        step: 500,
                        minimum: 1000,
                        maximum: 100000,
                        numeric: true,
                      ),
                      const Divider(height: 25),
                      _GoalRow(
                        icon: Icons.directions_run_rounded,
                        label: 'Weekly runs',
                        helper: 'A run or jog at your pace',
                        controller: _weeklyRuns,
                        suffix: 'runs',
                        step: 1,
                        minimum: 0,
                        maximum: 100,
                        numeric: true,
                      ),
                      const Divider(height: 25),
                      _GoalRow(
                        icon: Icons.route_outlined,
                        label: 'Monthly distance',
                        helper: 'Estimated walking distance',
                        controller: _monthlyDistance,
                        suffix: 'km',
                        step: 5,
                        minimum: 0,
                        maximum: 10000,
                        numeric: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: palette.coral, height: 1.4)),
                if (_savedMessage != null)
                  Text(_savedMessage!, style: TextStyle(color: palette.leaf, fontWeight: FontWeight.w600)),
                const SizedBox(height: 11),
                PrimaryAction(
                  label: 'Save my goals',
                  icon: Icons.check_rounded,
                  busy: _saving,
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: 13),
                Text(
                  'This optional suggestion uses recent steps and, when provided, your age, height, weight and gender. It’s a gentle starting point, not a medical target.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...[
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('GOALS UNAVAILABLE'),
                      const SizedBox(height: 7),
                      Text(_error ?? 'Could not load your goals.', style: Theme.of(context).textTheme.bodyMedium),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.icon,
    required this.label,
    required this.helper,
    required this.controller,
    required this.suffix,
    required this.step,
    required this.minimum,
    required this.maximum,
    required this.numeric,
  });
  final IconData icon;
  final String label;
  final String helper;
  final TextEditingController controller;
  final String suffix;
  final int step;
  final int minimum;
  final int maximum;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: context.palette.leaf),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                Text(helper, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          _AdjustButton(
            icon: Icons.remove_rounded,
            label: 'Decrease $label',
            onPressed: () => _adjust(-step),
          ),
          SizedBox(
            width: 74,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(decimal: !numeric),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _AdjustButton(
            icon: Icons.add_rounded,
            label: 'Increase $label',
            onPressed: () => _adjust(step),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 30,
            child: Text(suffix, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.clip),
          ),
        ],
      );

  void _adjust(int difference) {
    final value = double.tryParse(controller.text) ?? 0;
    final next = (value + difference)
        .clamp(minimum.toDouble(), maximum.toDouble())
        .toDouble();
    controller.text = numeric ? next.round().toString() : next.toStringAsFixed(0);
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      );
}

String _formatCount(int value) => value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

String _formatDistance(double value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
