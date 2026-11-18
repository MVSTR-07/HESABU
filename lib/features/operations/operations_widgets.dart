import 'package:flutter/material.dart';

import '../../ui/formatters.dart';
import '../../ui/shared.dart';

String operationId(String prefix) =>
    '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}';

int? parseKesAmount(String value) {
  final number = double.tryParse(value.trim().replaceAll(',', ''));
  if (number == null || !number.isFinite || number <= 0) return null;
  return (number * 100).round();
}

int? parseWholeNumber(String value, {bool allowZero = false}) {
  final number = int.tryParse(value.trim());
  if (number == null || number < (allowZero ? 0 : 1)) return null;
  return number;
}

Future<DateTime?> pickOperationDate(
  BuildContext context,
  DateTime initial,
) async {
  final kenya = initial.toUtc().add(const Duration(hours: 3));
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime(kenya.year, kenya.month, kenya.day),
    firstDate: DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (picked == null) return null;
  return DateTime.utc(picked.year, picked.month, picked.day, 9);
}

Future<bool> confirmOperationDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text('This removes the saved record from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

class OperationsPageFrame extends StatelessWidget {
  const OperationsPageFrame({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.children,
    super.key,
  });
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ContentWidth(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 150),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(subtitle),
        const SizedBox(height: 12),
        const PrivacyNote(),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 8, children: actions),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

class OperationsSection extends StatelessWidget {
  const OperationsSection({
    required this.title,
    required this.child,
    super.key,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );
}

class OperationMetric extends StatelessWidget {
  const OperationMetric(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: GlassPanel(
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    ),
  );
}

class OperationEmpty extends StatelessWidget {
  const OperationEmpty(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(message),
  );
}

String moneyLabel(int minor) => formatKes(minor);
