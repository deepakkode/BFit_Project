import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'palette.dart';

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      );
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderRadius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? context.palette.surface,
          border: Border.all(color: context.palette.line),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    required this.label,
    required this.onPressed,
    super.key,
    this.busy = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: context.palette.forest,
            foregroundColor: Colors.white,
            disabledBackgroundColor: context.palette.forest.withOpacity(0.56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: busy
              ? const SizedBox.square(
                  dimension: 21,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, size: 19),
                    ],
                  ],
                ),
        ),
      );
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.steps,
    required this.goal,
    super.key,
    this.available = true,
  });
  final int steps;
  final int goal;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final progress =
        goal <= 0 ? 0.0 : (steps / goal).clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 206,
      height: 206,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          track: Colors.white.withOpacity(0.16),
          active: context.palette.citrus,
        ),
        child: Semantics(
          container: true,
          excludeSemantics: true,
          label: available
              ? '$steps of $goal steps, ${(progress * 100).round()} percent'
              : 'Daily step count unavailable',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Eyebrow('TODAY', color: Color(0xFFCBDBD0)),
              const SizedBox(height: 7),
              Text(
                available ? _formatSteps(steps) : '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 37,
                  height: 1.02,
                  letterSpacing: -1.6,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'of ${_formatSteps(goal)} steps',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.73), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSteps(int count) {
    final value = count < 0 ? 0 : count;
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}m';
    return value.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(
      {required this.progress, required this.track, required this.active});
  final double progress;
  final Color track;
  final Color active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bounds = rect.deflate(9);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = active
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(bounds, -1.5708, 6.2832, false, trackPaint);
    if (progress > 0) {
      canvas.drawArc(bounds, -1.5708, 6.2832 * progress, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.active != active;
}
