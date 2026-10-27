import 'package:flutter/material.dart';

import '../../core/customers/customer_analysis.dart';
import '../../data/customer_repository.dart';
import '../../data/local_store.dart';
import '../../ui/shared.dart';

class CustomerSettings extends StatefulWidget {
  const CustomerSettings({required this.store, super.key});
  final LocalStore store;
  @override
  State<CustomerSettings> createState() => _CustomerSettingsState();
}

class _CustomerSettingsState extends State<CustomerSettings> {
  late final TextEditingController risk, lost, message;
  String? status;
  @override
  void initState() {
    super.initState();
    final repo = CustomerRepository.settings(widget.store);
    risk = TextEditingController(text: repo.config.atRisk.toString());
    lost = TextEditingController(text: repo.config.lost.toString());
    message = TextEditingController(text: repo.template);
  }

  @override
  void dispose() {
    risk.dispose();
    lost.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer follow-up settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Flag customers when days since their last payment exceed their own median purchase gap multiplied by these values. At least two different purchase dates are needed.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: risk,
                  decoration: const InputDecoration(
                    labelText: 'At Risk multiplier',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: lost,
                  decoration: const InputDecoration(
                    labelText: 'Lost multiplier',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: message,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Editable SMS template · use {name}',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              try {
                CustomerRepository.settings(widget.store).saveConfig(
                  DropOffConfig(
                    atRisk: double.parse(risk.text),
                    lost: double.parse(lost.text),
                  ),
                  message.text,
                );
                setState(() => status = 'Customer settings saved.');
              } catch (_) {
                setState(
                  () => status = 'Enter a positive At Risk multiplier and a larger Lost multiplier.',
                );
              }
            },
            child: const Text('Save customer settings'),
          ),
          if (status != null) Text(status!),
        ],
      ),
    ),
  );
}
