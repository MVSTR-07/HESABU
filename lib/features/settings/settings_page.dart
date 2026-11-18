import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../ui/shared.dart';
import '../customers/customer_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.controller, super.key});
  final AppController controller;

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cache and saved business data?'),
        content: const Text(
          'This removes imported statements, sales and expense records, stock records, customer merges, saved results and cached files from HESABU. Your demo account, appearance settings and original files outside HESABU are preserved. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear business data and cache'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.clearCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved business data and cache cleared. Demo account and settings preserved.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cache could not be fully cleared. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data and clear cache?'),
        content: const Text(
          'This permanently removes this device’s HESABU database, demo profile, preferences and cached files. Your original files outside HESABU are not touched. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.deleteAllData();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'All local data and cache deleted. A new empty encrypted database is ready.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Deletion could not finish. Storage is locked. Restart HESABU and retry deletion.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ContentWidth(
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        GlassPanel(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make it yours',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ThemeMode>(
                  initialValue: controller.themeMode,
                  decoration: const InputDecoration(labelText: 'Appearance'),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Follow device'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: controller.busy
                      ? null
                      : (v) {
                          if (v != null) controller.setTheme(v);
                        },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Currency: KES · Dates: dd/MM/yyyy · Time zone: Africa/Nairobi',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account & plan · local demo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(controller.email ?? 'No demo profile on this device'),
                const SizedBox(height: 8),
                const Text(
                  'No server is connected. This switch only tests free/paid access; it does not create a subscription or charge money.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Preview paid plan'),
                  value: controller.paid,
                  onChanged: controller.busy ? null : controller.setDemoPaid,
                ),
                if (controller.signedIn)
                  OutlinedButton(
                    onPressed: controller.busy ? null : controller.signOut,
                    child: const Text('Log out of demo'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const GlassPanel(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrivacyNote(),
                SizedBox(height: 16),
                Text('AI add-on: off · Not installed'),
                SizedBox(height: 8),
                Text(
                  'Base analysis uses local code. An optional paid AI add-on is reserved for Stage 6 and will require consent showing exactly what would be sent.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data, your control',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Clear cache also erases imported statements, sales, expenses, stock records, customer merges and results. Delete all data resets the entire local workspace.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => _clearCache(context),
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Clear cache'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: controller.busy
                          ? null
                          : () => _delete(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete all data / clear cache'),
                    ),
                  ],
                ),
                if (controller.busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
        CustomerSettings(store: controller.store),
        const SizedBox(height: 24),
      ],
    ),
  );
}
