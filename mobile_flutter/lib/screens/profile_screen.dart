import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/palette.dart';
import '../core/widgets.dart';
import '../services/reminder_service.dart';
import 'profile_form_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  ReminderSettings _reminder = const ReminderSettings(enabled: false, hour: 18, minute: 0);
  bool _reminderLoading = true;
  bool _reminderSaving = false;
  String? _reminderError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshReminderSchedule());
    }
  }

  Future<void> _refreshReminderSchedule() async {
    try {
      await ReminderService.instance.initialize();
      if (mounted) setState(() => _reminderError = null);
    } catch (error) {
      if (mounted) {
        setState(() => _reminderError =
            error.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  Future<void> _loadReminder() async {
    try {
      await ReminderService.instance.initialize();
    } catch (error) {
      _reminderError = error.toString().replaceFirst('Bad state: ', '');
    }
    try {
      _reminder = await ReminderService.instance.readSettings();
    } catch (_) {
      _reminderError ??= 'Reminder settings could not be loaded.';
    } finally {
      if (mounted) setState(() => _reminderLoading = false);
    }
  }

  Future<void> _changeReminder(bool enabled, {int? hour, int? minute}) async {
    final previous = _reminder;
    setState(() {
      _reminderSaving = true;
      _reminderError = null;
      _reminder = ReminderSettings(
        enabled: enabled,
        hour: hour ?? previous.hour,
        minute: minute ?? previous.minute,
      );
    });
    try {
      await ReminderService.instance.setEnabled(
        enabled,
        hour: hour ?? previous.hour,
        minute: minute ?? previous.minute,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _reminder = previous;
          _reminderError = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _reminderSaving = false);
    }
  }

  Future<void> _pickReminderTime() async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
      helpText: 'Choose a gentle reminder time',
    );
    if (chosen == null) return;
    await _changeReminder(
      _reminder.enabled,
      hour: chosen.hour,
      minute: chosen.minute,
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of BFit?'),
        content: const Text('Your account and server history stay safe. You’ll need your password to sign back in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep me signed in')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirm == true) await widget.controller.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(21, 20, 21, 30),
          children: [
            const Eyebrow('YOUR SPACE'),
            const SizedBox(height: 7),
            Text('A few things about you.', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 21),
            SurfacePanel(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 53,
                    height: 53,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.surfaceRaised,
                    ),
                    child: Center(
                      child: Text(
                        user.name.trim().isEmpty ? 'B' : user.name.trim()[0].toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.leaf),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ProfileFormScreen(controller: widget.controller, requiredForUse: false),
                    )),
                    icon: Icon(Icons.edit_outlined, color: palette.leaf),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 23),
            const SectionTitle('Your details'),
            const SizedBox(height: 11),
            SurfacePanel(
              padding: const EdgeInsets.fromLTRB(17, 5, 17, 5),
              borderRadius: 19,
              child: Column(
                children: [
                  _DetailRow(label: 'Age', value: user.age == null ? 'Not added' : '${user.age} years'),
                  const Divider(height: 1),
                  _DetailRow(label: 'Height', value: user.heightCm == null ? 'Not added' : '${user.heightCm!.toStringAsFixed(0)} cm'),
                  const Divider(height: 1),
                  _DetailRow(label: 'Weight', value: user.weightKg == null ? 'Not added' : '${user.weightKg!.toStringAsFixed(1)} kg'),
                  const Divider(height: 1),
                  _DetailRow(label: 'Gender', value: user.gender == null || user.gender!.isEmpty ? 'Not shared' : user.gender!),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Preferences'),
            const SizedBox(height: 11),
            SurfacePanel(
              padding: const EdgeInsets.fromLTRB(17, 2, 15, 2),
              borderRadius: 19,
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: widget.controller.isDark,
                    onChanged: widget.controller.setDarkMode,
                    title: const Text('Evening colours'),
                    subtitle: const Text('A calmer dark palette'),
                    secondary: Icon(Icons.dark_mode_outlined, color: palette.leaf),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.notifications_active_outlined, color: palette.leaf),
                    title: const Text('Daily reminder'),
                    subtitle: Text(
                      _reminderLoading
                          ? 'Loading reminder settings…'
                          : _reminder.enabled
                              ? 'Around ${_timeLabel(_reminder.hour, _reminder.minute)} local time each day'
                              : 'A gentle nudge, on your local clock',
                    ),
                    trailing: _reminderSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch.adaptive(
                            value: _reminder.enabled,
                            onChanged: _reminderLoading ? null : (value) => _changeReminder(value),
                          ),
                    onTap: _reminder.enabled && !_reminderLoading && !_reminderSaving
                        ? _pickReminderTime
                        : null,
                  ),
                  if (_reminder.enabled)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _reminderSaving ? null : _pickReminderTime,
                        icon: const Icon(Icons.schedule_rounded, size: 18),
                        label: const Text('Change reminder time'),
                      ),
                    ),
                ],
              ),
            ),
            if (_reminderError != null) ...[
              const SizedBox(height: 8),
              Text(_reminderError!, style: TextStyle(color: palette.coral, height: 1.4)),
            ],
            const SizedBox(height: 9),
            Text(
              'Reminders use your phone’s local time and refresh after a time-zone change when BFit opens or resumes. Android Doze, battery settings, or disabled notifications can delay or prevent delivery; this is not an exact-time alert.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            SurfacePanel(
              padding: const EdgeInsets.all(17),
              color: palette.surfaceRaised,
              borderRadius: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: palette.leaf),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Made for everyday wellbeing', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Distance and energy are approximate estimates, not medical advice. Activity recognition runs through the BFit service.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.coral,
                minimumSize: const Size.fromHeight(51),
                side: BorderSide(color: palette.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 17),
            Center(
              child: Text(
                'BFit · everyday movement, more thoughtfully',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      );
}

String _timeLabel(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'AM' : 'PM';
  return '$h:${minute.toString().padLeft(2, '0')} $suffix';
}
