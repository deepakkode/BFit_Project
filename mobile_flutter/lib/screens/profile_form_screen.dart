import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_controller.dart';
import '../core/palette.dart';
import '../core/widgets.dart';

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({
    required this.controller,
    required this.requiredForUse,
    super.key,
  });
  final AppController controller;
  final bool requiredForUse;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late String? _gender;
  bool _busy = false;
  String? _error;
  String? _notice;
  bool _noticeIsWarning = false;

  @override
  void initState() {
    super.initState();
    final user = widget.controller.user!;
    _age = TextEditingController(text: user.age?.toString() ?? '');
    _height = TextEditingController(text: user.heightCm?.toStringAsFixed(0) ?? '');
    _weight = TextEditingController(text: user.weightKg?.toStringAsFixed(1) ?? '');
    _gender = user.gender;
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.controller.updateProfile(
        age: int.parse(_age.text),
        heightCm: double.parse(_height.text),
        weightKg: double.parse(_weight.text),
        gender: _gender == 'Prefer not to say' ? null : _gender,
      );
      if (mounted) {
        setState(() {
          _notice = result ?? 'Your details are saved.';
          _noticeIsWarning = result != null &&
              (result.contains('could not') || result.contains('unavailable'));
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Profile could not be saved. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;
    final palette = context.palette;
    return Scaffold(
      appBar: widget.requiredForUse
          ? null
          : AppBar(title: const Text('Your details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(23, 27, 23, 28),
          child: Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.requiredForUse) ...[
                  const Eyebrow('A GOOD PLACE TO BEGIN'),
                  const SizedBox(height: 12),
                  Text('Let’s make this\nfeel like yours, ${user.name.split(' ').first}.',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 11),
                  Text(
                    'A few details help BFit estimate distance and suggest a gradual daily step goal. These are optional to share beyond what is needed for your profile.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 30),
                ] else ...[
                  const Eyebrow('YOUR PROFILE'),
                  const SizedBox(height: 7),
                  Text('A little context,\na better fit.',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 23),
                ],
                _numberField('Age', _age, min: 13, max: 120, wholeNumber: true),
                const SizedBox(height: 14),
                _numberField('Height · cm', _height, min: 1, max: 260),
                const SizedBox(height: 14),
                _numberField('Weight · kg', _weight, min: 1, max: 500),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender · optional'),
                  items: const [
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                    DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: 15),
                SurfacePanel(
                  padding: const EdgeInsets.all(16),
                  color: palette.surfaceRaised,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 19, color: palette.leaf),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Estimates are approximate and are not medical measurements. You can update these details any time.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: TextStyle(color: palette.coral)),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 14),
                  SurfacePanel(
                    padding: const EdgeInsets.all(13),
                    color: _noticeIsWarning ? palette.surfaceRaised : palette.surface,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _noticeIsWarning
                              ? Icons.info_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 19,
                          color: _noticeIsWarning ? palette.coral : palette.leaf,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _notice!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: _noticeIsWarning ? palette.ink : palette.leaf,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 23),
                PrimaryAction(
                  label: widget.requiredForUse ? 'Continue to BFit' : 'Save changes',
                  icon: Icons.arrow_forward_rounded,
                  busy: _busy,
                  onPressed: _busy ? null : _save,
                ),
                if (widget.requiredForUse)
                  Center(
                    child: TextButton.icon(
                      onPressed: widget.controller.signOut,
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: const Text('Sign out instead'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField(
    String label,
    TextEditingController controller, {
    required double min,
    required double max,
    bool wholeNumber = false,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final number = double.tryParse(value ?? '');
          if (number == null || number < min || number > max) {
            return 'Enter a value between ${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)}.';
          }
          if (wholeNumber && number != number.roundToDouble()) {
            return 'Enter a whole number.';
          }
          return null;
        },
      );
}
