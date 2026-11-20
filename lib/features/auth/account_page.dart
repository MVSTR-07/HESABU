import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../ui/shared.dart';

// This is still local demo identity; the password protects workspace
// administration on this device and is never uploaded or stored as plaintext.
class AccountPage extends StatefulWidget {
  const AccountPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_create && _password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    final accountError = widget.controller.enterDemo(_email.text, create: _create);
    if (accountError != null) {
      setState(() => _error = accountError);
      return;
    }
    if (_create) {
      final passwordError = widget.controller.setAccountPassword(_password.text);
      if (passwordError != null) {
        setState(() => _error = passwordError);
      }
    } else if (widget.controller.hasAccountPassword &&
        !widget.controller.verifyAccountPassword(_password.text)) {
      setState(() => _error = 'Incorrect password.');
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassPanel(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: HesabuBrand(),
                ),
                const SizedBox(height: 28),
                Text(
                  _create ? 'Create your workspace' : 'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'LOCAL DEMO ONLY\nYour email and a salted password verifier stay on this device. No password is uploaded or stored as plaintext.',
                ),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Sign up')),
                    ButtonSegment(value: false, label: Text('Log in')),
                  ],
                  selected: {_create},
                  onSelectionChanged: (v) => setState(() {
                    _create = v.single;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: _create ? 'Create password' : 'Password',
                    helperText: _create ? 'At least 8 characters' : null,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submit,
                  child: Text(
                    _create ? 'Create demo profile' : 'Log in to demo',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => widget.controller.navigate(AppPage.intro),
                  child: const Text('Back to introduction'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
