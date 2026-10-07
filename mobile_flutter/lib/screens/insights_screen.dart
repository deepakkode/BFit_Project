import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_controller.dart';
import '../core/models.dart';
import '../core/palette.dart';
import '../core/widgets.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _monthly = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _days = [];
  Map<String, dynamic> _totals = {};
  DateTime _month = DateTime.now();

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
      final response = _monthly
          ? await widget.controller.api.monthly(_month)
          : await widget.controller.api.weekly();
      _days = (response['days'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _totals = response['totals'] is Map
          ? Map<String, dynamic>.from(response['totals'] as Map)
          : {};
    } on ApiException catch (error) {
      _error = error.message;
      _days = [];
      _totals = {};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = asInt(_totals['total_steps']);
    final daysWithSteps = _days.where((day) => asInt(day['total_steps']) > 0).length;
    final average = daysWithSteps == 0 ? 0 : (steps / daysWithSteps).round();
    final distance = asDouble(_totals['total_distance']);
    final runs = asInt(_totals['running_minutes']);
    final chartValues = _days.map((day) => asDouble(day['total_steps'])).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(21, 20, 21, 30),
            children: [
              const Eyebrow('YOUR PATTERNS'),
              const SizedBox(height: 7),
              Text('Notice the little wins.', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'A wider view of the movement you’ve made.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 23),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('This week')),
                  ButtonSegment(value: true, label: Text('This month')),
                ],
                selected: {_monthly},
                onSelectionChanged: (value) {
                  setState(() => _monthly = value.first);
                  _load();
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: context.palette.surface,
                  selectedBackgroundColor: context.palette.citrus.withOpacity(0.52),
                  side: BorderSide(color: context.palette.line),
                ),
              ),
              const SizedBox(height: 17),
              if (_loading && _days.isEmpty)
                const _InsightPanel(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_error != null && _days.isEmpty)
                _InsightError(message: _error!, onRetry: _load)
              else if (_days.isEmpty)
                const _InsightPanel(
                  child: Text('There’s no movement summary to show yet. Keep your phone with you during the day and check back soon.'),
                )
              else ...[
                _ChartPanel(
                  days: _days,
                  values: chartValues,
                  monthly: _monthly,
                  month: _month,
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _StatPanel(
                        label: 'TOTAL STEPS',
                        value: _formatCount(steps),
                        footer: _monthly ? 'this month' : 'this week',
                        icon: Icons.directions_walk_rounded,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _StatPanel(
                        label: 'DAILY AVERAGE',
                        value: _formatCount(average),
                        footer: 'on active days',
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _StatPanel(
                        label: 'DISTANCE',
                        value: '${distance.toStringAsFixed(1)} km',
                        footer: 'estimated',
                        icon: Icons.route_outlined,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _StatPanel(
                        label: 'RUNNING',
                        value: _formatMinutes(runs),
                        footer: 'recognised time',
                        icon: Icons.directions_run_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                SurfacePanel(
                  padding: const EdgeInsets.all(17),
                  color: context.palette.surfaceRaised,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: context.palette.leaf),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          daysWithSteps == 0
                              ? 'Your next walk starts a new pattern. Keep it comfortable and make it yours.'
                              : 'Your step average is based on days with recorded movement. A steady routine matters more than any single high day.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.ink),
                        ),
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

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.days,
    required this.values,
    required this.monthly,
    required this.month,
  });
  final List<Map<String, dynamic>> days;
  final List<double> values;
  final bool monthly;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (maximum, value) => value > maximum ? value : maximum);
    final average = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
    final caption = monthly
        ? '${_monthName(month.month)} ${month.year}'
        : _weekCaption(days);
    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  maxValue == 0 ? 'No recorded steps yet' : caption,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: context.palette.leaf, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('Steps', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: Semantics(
              label: '${values.length} day step chart. Highest day ${_formatCount(maxValue.round())} steps.',
              child: CustomPaint(
                painter: _StepsChartPainter(
                  values: values,
                  maxValue: maxValue,
                  average: average,
                  palette: context.palette,
                  monthly: monthly,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: monthly
                ? [
                    Text('1 ${_monthName(month.month)}', style: Theme.of(context).textTheme.bodySmall),
                    Text('${days.length} days', style: Theme.of(context).textTheme.bodySmall),
                    Text('${days.length} ${_monthName(month.month)}', style: Theme.of(context).textTheme.bodySmall),
                  ]
                : days.take(7).map((day) {
                    final date = asDate(day['summary_date']);
                    return Text(date == null ? '' : _weekday(date.weekday),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10));
                  }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StepsChartPainter extends CustomPainter {
  const _StepsChartPainter({
    required this.values,
    required this.maxValue,
    required this.average,
    required this.palette,
    required this.monthly,
  });
  final List<double> values;
  final double maxValue;
  final double average;
  final BFitPalette palette;
  final bool monthly;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 35.0;
    const top = 4.0;
    const bottom = 10.0;
    final chartWidth = size.width - left;
    final chartHeight = size.height - top - bottom;
    final maxScale = maxValue <= 0 ? 1000.0 : maxValue * 1.12;
    final gridPaint = Paint()
      ..color = palette.line
      ..strokeWidth = 1;
    final gridText = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 4; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
      final label = maxScale * (3 - i) / 3;
      gridText.text = TextSpan(
        text: _axisValue(label),
        style: TextStyle(color: palette.muted, fontSize: 9),
      );
      gridText.layout(maxWidth: left - 5);
      gridText.paint(canvas, Offset(0, y - gridText.height / 2));
    }
    if (values.isEmpty) return;
    final slot = chartWidth / values.length;
    final barWidth = (slot * (monthly ? 0.58 : 0.5)).clamp(3.0, 20.0).toDouble();
    final barPaint = Paint()..color = palette.leaf;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final height = chartHeight * value / maxScale;
      final x = left + slot * i + (slot - barWidth) / 2;
      final y = top + chartHeight - height;
      final radius = Radius.circular(barWidth / 2);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, height.clamp(1, chartHeight).toDouble()),
        topLeft: radius,
        topRight: radius,
      );
      canvas.drawRRect(rect, barPaint);
    }
    if (average > 0) {
      final y = top + chartHeight - chartHeight * average / maxScale;
      final dash = Paint()
        ..color = palette.coral.withOpacity(0.75)
        ..strokeWidth = 1.2;
      for (var x = left; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 4).clamp(left, size.width).toDouble(), y),
          dash,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StepsChartPainter old) =>
      old.values != values ||
      old.maxValue != maxValue ||
      old.average != average ||
      old.palette != palette ||
      old.monthly != monthly;
}

class _StatPanel extends StatelessWidget {
  const _StatPanel({
    required this.label,
    required this.value,
    required this.footer,
    required this.icon,
  });
  final String label;
  final String value;
  final String footer;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SurfacePanel(
        padding: const EdgeInsets.fromLTRB(14, 14, 11, 13),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 15, color: context.palette.leaf),
              const SizedBox(width: 6),
              Flexible(child: Eyebrow(label)),
            ]),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
            ),
            const SizedBox(height: 2),
            Text(footer, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
          ],
        ),
      );
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SurfacePanel(
        padding: const EdgeInsets.all(23),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!,
          child: child,
        ),
      );
}

class _InsightError extends StatelessWidget {
  const _InsightError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('INSIGHTS UNAVAILABLE'),
            const SizedBox(height: 6),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
}

String _monthName(int month) =>
    const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month - 1];

String _weekday(int day) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1];

String _weekCaption(List<Map<String, dynamic>> days) {
  if (days.isEmpty) return 'This week';
  final start = asDate(days.first['summary_date']);
  final end = asDate(days.last['summary_date']);
  if (start == null || end == null) return 'This week';
  return '${_monthName(start.month).substring(0, 3)} ${start.day}–${end.day}';
}

String _axisValue(double value) {
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
  return value.round().toString();
}

String _formatCount(num value) => value.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

String _formatMinutes(int minutes) =>
    minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h ${minutes % 60}m';
