import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_controller.dart';
import '../core/models.dart';
import '../core/palette.dart';
import '../core/wellness_metrics.dart';
import '../core/widgets.dart';
import '../services/activity_tracker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {required this.controller, required this.tracker, super.key});
  final AppController controller;
  final ActivityTracker tracker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ActivityReading? _reading;
  StepDay? _steps;
  GoalSettings? _goals;
  Map<String, dynamic>? _mix;
  String? _activityError;
  String? _stepsError;
  bool _loading = true;
  bool _refreshing = false;
  bool _refreshAgain = false;
  int _seenGoalRevision = 0;

  @override
  void initState() {
    super.initState();
    _seenGoalRevision = widget.controller.goalRevision;
    widget.controller.addListener(_onGoalsChanged);
    widget.tracker.addListener(_onTrackerChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGoalsChanged);
    widget.tracker.removeListener(_onTrackerChanged);
    super.dispose();
  }

  void _onGoalsChanged() {
    final revision = widget.controller.goalRevision;
    if (revision == _seenGoalRevision) return;
    _seenGoalRevision = revision;
    unawaited(_load());
  }

  void _onTrackerChanged() {
    if (!mounted) return;
    if (widget.tracker.latestActivity != null) {
      _reading = widget.tracker.latestActivity;
      _activityError = null;
    }
    setState(() {});
  }

  Future<void> _load() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    if (mounted)
      setState(() {
        if (_reading == null && _steps == null) _loading = true;
      });
    try {
      try {
        _reading = await widget.controller.api.currentActivity();
        _activityError = null;
      } on ApiException catch (error) {
        _activityError = error.message;
      }
      try {
        _steps = await widget.controller.api.todaySteps();
        _stepsError = null;
      } on ApiException catch (error) {
        _stepsError = error.message;
      }
      try {
        _goals = await widget.controller.api.goals();
      } on ApiException {
        _goals = null;
      }
      try {
        _mix = await widget.controller.api.todayActivity();
      } on ApiException {
        _mix = null;
      }
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
      if (_refreshAgain && mounted) {
        _refreshAgain = false;
        unawaited(_load());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;
    final palette = context.palette;
    final serverSteps = _steps?.steps ?? 0;
    final localSteps =
        widget.tracker.stepDate == _todayUtc() ? widget.tracker.localSteps : 0;
    final steps = localSteps > serverSteps ? localSteps : serverSteps;
    final stepAvailable = _steps != null || localSteps > 0;
    final goal = _goals?.dailySteps ?? starterDailyStepGoal;
    final metrics = estimateWalkingMetrics(steps, user);
    final reading = _reading ?? const ActivityReading();
    final freshness = activityFreshness(reading, DateTime.now().toUtc());
    final durations = _mix?['duration_seconds'] is Map
        ? Map<String, dynamic>.from(_mix!['duration_seconds'] as Map)
        : const <String, dynamic>{};
    final walkMinutes = asInt(durations['Walking']) ~/ 60;
    final runMinutes = asInt(durations['Running']) ~/ 60;
    final restMinutes =
        (asInt(durations['Sitting']) + asInt(durations['Standing'])) ~/ 60;
    final activityTotal = walkMinutes + runMinutes + restMinutes;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: palette.leaf,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(21, 17, 21, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(_todayLabel()),
                        const SizedBox(height: 4),
                        Text(
                          'A good day to move, ${user.name.split(' ').first}.',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 19),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.surfaceRaised,
                    ),
                    child:
                        Icon(Icons.spa_outlined, color: palette.leaf, size: 21),
                  ),
                ],
              ),
              const SizedBox(height: 21),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
                decoration: BoxDecoration(
                  color: palette.forest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Eyebrow('YOUR DAILY RHYTHM',
                              color: Color(0xFFCBDBD0)),
                        ),
                        Icon(
                          Icons.directions_walk_rounded,
                          size: 19,
                          color: palette.citrus,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      label: !stepAvailable
                          ? 'Daily step progress unavailable'
                          : ' steps of  steps,  percent complete',
                      child: ProgressRing(
                        steps: steps,
                        goal: goal,
                        available: stepAvailable,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        !stepAvailable
                            ? 'Daily progress unavailable'
                            : steps >= goal
                                ? 'You met today’s step intention.'
                                : '${_formatCount((goal - steps).clamp(0, goal).toInt())} to your daily intention',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _stepsError != null
                          ? localSteps > 0
                              ? 'Phone total saved · waiting to reconnect'
                              : 'Step total unavailable · pull to retry'
                          : widget.tracker.stepsStatus,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Earlier phone step history may not be recoverable in BFit.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.58), fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                    if (_goals == null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Saved goal unavailable · showing the 6,000-step starting point',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
              if (_stepsError != null && localSteps == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SurfacePanel(
                    padding: const EdgeInsets.fromLTRB(14, 11, 11, 11),
                    borderRadius: 15,
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_outlined,
                            size: 18, color: palette.coral),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _stepsError!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Retry step total',
                          onPressed: _load,
                          icon:
                              Icon(Icons.refresh_rounded, color: palette.leaf),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MetricPanel(
                      label: 'DISTANCE',
                      value: !stepAvailable
                          ? '—'
                          : metrics.distanceKm.toStringAsFixed(2),
                      unit: 'km',
                      icon: Icons.route_outlined,
                      footer: !stepAvailable ? 'Not available' : 'Estimate',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricPanel(
                      label: 'ENERGY',
                      value: !stepAvailable
                          ? '—'
                          : metrics.caloriesKcal.toStringAsFixed(0),
                      unit: 'kcal',
                      icon: Icons.bolt_outlined,
                      footer: !stepAvailable ? 'Not available' : 'Estimate',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SectionTitle(
                'Right now',
                trailing: _activityError == null
                    ? null
                    : IconButton(
                        tooltip: 'Try again',
                        onPressed: _load,
                        icon: Icon(Icons.refresh_rounded, color: palette.leaf),
                      ),
              ),
              const SizedBox(height: 12),
              SurfacePanel(
                padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
                child: Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: _activityColor(reading.activity, palette)
                            .withOpacity(0.13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _activityIcon(reading.activity),
                        color: _activityColor(reading.activity, palette),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reading.activity == null
                                ? 'Waiting for a reading'
                                : displayActivityName(reading.activity),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            reading.activity == null
                                ? _activityError ??
                                    widget.tracker.activityStatus
                                : freshness.note,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                    if (freshness.isStale)
                      Icon(Icons.schedule_rounded,
                          color: palette.muted, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionTitle('How today is moving'),
              const SizedBox(height: 6),
              Text(
                activityTotal == 0
                    ? _mix == null
                        ? 'Activity mix is unavailable right now.'
                        : 'Your activity mix will take shape as the day goes on.'
                    : '$activityTotal minutes recognised today',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 13),
              _MovementMix(
                walking: walkMinutes,
                running: runMinutes,
                rest: restMinutes,
                total: activityTotal,
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
                decoration: BoxDecoration(
                  color: palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.wb_sunny_outlined,
                        color: palette.leaf, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('A NOTE FOR TODAY'),
                          const SizedBox(height: 7),
                          Text(
                            quoteForDate(DateTime.now()),
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _todayUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _todayLabel() {
    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]} · ${months[now.month - 1]} ${now.day}';
  }

  String _formatCount(int count) => count.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.footer = 'Estimate',
  });
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final String footer;

  @override
  Widget build(BuildContext context) => SurfacePanel(
        padding: const EdgeInsets.fromLTRB(15, 16, 13, 15),
        borderRadius: 19,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: context.palette.leaf),
                const SizedBox(width: 7),
                Eyebrow(label),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 25)),
                ),
                const SizedBox(width: 5),
                Text(unit, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 2),
            Text(footer,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11)),
          ],
        ),
      );
}

class _MovementMix extends StatelessWidget {
  const _MovementMix({
    required this.walking,
    required this.running,
    required this.rest,
    required this.total,
  });
  final int walking;
  final int running;
  final int rest;
  final int total;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Walk', walking, context.palette.leaf),
      ('Run', running, context.palette.coral),
      ('Rest', rest, context.palette.surfaceRaised),
    ];
    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
      borderRadius: 19,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 9,
              child: Row(
                children: total == 0
                    ? [
                        Expanded(
                            child: ColoredBox(
                                color: context.palette.surfaceRaised))
                      ]
                    : values.map((entry) {
                        final fraction = entry.$2 / total;
                        return Expanded(
                          flex:
                              (fraction * 1000).round().clamp(1, 1000).toInt(),
                          child: ColoredBox(color: entry.$3),
                        );
                      }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: values.map((entry) {
              final minutes = entry.$2;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: entry.$3,
                        shape: BoxShape.circle,
                        border: entry.$1 == 'Rest'
                            ? Border.all(color: context.palette.line)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${entry.$1}  ${minutes}m',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

Color _activityColor(String? activity, BFitPalette palette) =>
    switch (activity) {
      'Walking' => palette.leaf,
      'Running' => palette.coral,
      'Standing' || 'Sitting' => palette.muted,
      _ => palette.leaf,
    };

IconData _activityIcon(String? activity) => switch (activity) {
      'Walking' => Icons.directions_walk_rounded,
      'Running' => Icons.directions_run_rounded,
      'Standing' || 'Sitting' => Icons.self_improvement_rounded,
      _ => Icons.sensors_rounded,
    };
