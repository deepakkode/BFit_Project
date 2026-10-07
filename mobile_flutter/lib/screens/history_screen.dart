import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_controller.dart';
import '../core/models.dart';
import '../core/palette.dart';
import '../core/widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<StepDay> _days = [];
  List<ActivitySession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        widget.controller.api.stepHistory(),
        widget.controller.api.activityHistory(),
      ]);
      _days = values[0] as List<StepDay>;
      _sessions = values[1] as List<ActivitySession>;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(21, 20, 21, 30),
              children: [
                const Eyebrow('A LOOK BACK'),
                const SizedBox(height: 7),
                Text('Your rhythm, over time.', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'A gentle record of the days you’ve been moving.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                const SectionTitle('Daily steps'),
                const SizedBox(height: 12),
                if (_loading && _days.isEmpty)
                  const _LoadingPanel()
                else if (_error != null && _days.isEmpty)
                  _ErrorPanel(message: _error!, onRetry: _load)
                else if (_days.isEmpty)
                  const _EmptyPanel(
                    icon: Icons.directions_walk_outlined,
                    title: 'Your first day is ahead',
                    message: 'Once your phone records steps, they’ll appear here day by day.',
                  )
                else
                  ..._days.take(14).map((day) => _StepHistoryRow(day: day)),
                const SizedBox(height: 25),
                const SectionTitle('Movement sessions'),
                const SizedBox(height: 7),
                Text(
                  'Recognised moments · sitting and standing shown as Rest',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_loading && _sessions.isEmpty)
                  const _LoadingPanel()
                else if (_sessions.isEmpty)
                  const _EmptyPanel(
                    icon: Icons.sensors_outlined,
                    title: 'No sessions just yet',
                    message: 'Movement sessions appear after the on-device sensors have collected a window.',
                  )
                else
                  ..._sessions.take(20).map((session) => _SessionRow(session: session)),
                if (_error != null && (_days.isNotEmpty || _sessions.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 13),
                    child: Text(
                      'Some history could not refresh: $_error',
                      style: TextStyle(color: context.palette.coral),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _StepHistoryRow extends StatelessWidget {
  const _StepHistoryRow({required this.day});
  final StepDay day;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderRadius: 17,
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: context.palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.calendar_today_outlined, size: 18, color: context.palette.leaf),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dateLabel(day.logDate), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('${day.distanceKm.toStringAsFixed(2)} km estimated',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                _format(day.steps),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
              const SizedBox(width: 4),
              Text('steps', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final ActivitySession session;

  @override
  Widget build(BuildContext context) {
    final name = session.activity == 'Sitting' || session.activity == 'Standing'
        ? 'Rest'
        : session.activity;
    final icon = name == 'Running'
        ? Icons.directions_run_rounded
        : name == 'Walking'
            ? Icons.directions_walk_rounded
            : Icons.self_improvement_rounded;
    final color = name == 'Running' ? context.palette.coral : context.palette.leaf;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: SurfacePanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        borderRadius: 17,
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${_time(session.startTime)} · ${(session.confidence * 100).round()}% confidence',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(_duration(session.durationSeconds),
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => SurfacePanel(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: context.palette.leaf, size: 24),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('CAN’T LOAD HISTORY'),
            const SizedBox(height: 6),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();
  @override
  Widget build(BuildContext context) => const SurfacePanel(
        padding: EdgeInsets.all(23),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

String _dateLabel(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final today = DateTime.now().toUtc();
  if (date.year == today.year && date.month == today.month && date.day == today.day) {
    return 'Today';
  }
  return '${date.day} ${months[date.month - 1]}';
}

String _time(DateTime value) =>
    '${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';

String _duration(int seconds) {
  final minutes = seconds ~/ 60;
  return minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h ${minutes % 60}m';
}

String _format(int value) => value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
