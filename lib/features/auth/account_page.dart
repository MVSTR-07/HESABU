import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../ui/shared.dart';

// TODO(real-auth): Keep the visible DEMO warning until genuine verified sign-in
// is connected. No password input, password storage, or password logging here.
class AccountPage extends StatefulWidget {
  const AccountPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  bool _create = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _error = widget.controller.enterDemo(_email.text, create: _create);
    });
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
                  'LOCAL DEMO ONLY\nThis email is saved in your encrypted database. No email is sent, no password is collected, and this is not secure account authentication.',
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
