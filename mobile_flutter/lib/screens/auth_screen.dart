import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_controller.dart';
import '../core/palette.dart';
import '../core/widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _gender;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await widget.controller.registerAndSignIn(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          age: int.tryParse(_age.text),
          heightCm: double.tryParse(_height.text),
          weightKg: double.tryParse(_weight.text),
          gender: _gender,
        );
      } else {
        await widget.controller.signIn(_email.text.trim(), _password.text);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiException
              ? error.message
              : 'Could not connect to BFit. Check your connection, then try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              26,
              24,
              26,
              28,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/brand/bfit-mark.png', width: 52, height: 52),
                        const SizedBox(width: 13),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BFit', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 3),
                            const Eyebrow('Balanced today · better tomorrow'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 43),
                    const Eyebrow('A LITTLE MORE IN TUNE'),
                    const SizedBox(height: 11),
                    Text(
                      _isRegister ? 'Make space for\nfeeling good.' : 'Move well.\nFeel well.',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 42),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'A thoughtful view of your everyday movement.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: palette.muted),
                    ),
                    if (widget.controller.bannerMessage != null) ...[
                      const SizedBox(height: 16),
                      SurfacePanel(
                        padding: const EdgeInsets.all(14),
                        color: palette.surfaceRaised,
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: palette.coral, size: 19),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                widget.controller.bannerMessage!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 31),
                    if (_isRegister) ...[
                      _input(
                        'Name',
                        _name,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter your name.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _input(
                      'Email',
                      _email,
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      validator: (value) {
                        if (value == null || !value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => value == null || value.length < 8
                          ? 'Use at least 8 characters.'
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                    ),
                    if (_isRegister) ...[
                      const SizedBox(height: 21),
                      const Eyebrow('PERSONALIZE YOUR START'),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Expanded(child: _input('Age', _age, keyboardType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(child: _input('Height · cm', _height, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _input('Weight · kg', _weight, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: const InputDecoration(labelText: 'Gender · optional'),
                              items: const [
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                                DropdownMenuItem(value: 'Prefer not to say', child: Text('Skip')),
                              ],
                              onChanged: (value) => setState(() => _gender = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'You can add these details later. BFit uses them only to make movement estimates and step suggestions more personal.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted, height: 1.4),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: Text(_error!, style: TextStyle(color: palette.coral, height: 1.4)),
                      ),
                    ],
                    const SizedBox(height: 23),
                    PrimaryAction(
                      label: _isRegister ? 'Create account' : 'Sign in',
                      icon: Icons.arrow_forward_rounded,
                      busy: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _isRegister = !_isRegister;
                                  _error = null;
                                }),
                        child: Text(_isRegister
                            ? 'Already have an account?  Sign in'
                            : 'New to BFit?  Create an account'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Your health data stays connected to your BFit account.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        validator: validator,
        decoration: InputDecoration(labelText: label),
      );
}
