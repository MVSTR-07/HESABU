import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_controller.dart';
import '../../core/customers/customer_analysis.dart';
import '../../data/customer_repository.dart';
import '../../data/local_statement_picker.dart';
import '../../ui/formatters.dart';
import '../../ui/shared.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late CustomerRepository repo;
  CustomerResults results = const CustomerResults([], [], 0);
  DateTime asOf = DateTime.now().toUtc();
  String? error, notice, sourceId, targetId;
  bool busy = false, storageFailed = false;
  @override
  void initState() {
    super.initState();
    try {
      repo = CustomerRepository(widget.controller.store);
      results = repo.analyse(asOf);
    } catch (_) {
      storageFailed = true;
      error = 'Customer storage could not be loaded. Restart the app or clear imports in Settings.';
    }
  }

  Future<void> task(FutureOr<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    widget.controller.setImportBusy(true);
    try {
      await action();
      final next = repo.analyse(asOf);
      if (mounted) {
        setState(() {
          results = next;
          sourceId = null;
          targetId = null;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'This operation could not finish. Check storage space and use a valid sales CSV. No data was sent.',
        );
      }
    } finally {
      widget.controller.setImportBusy(false);
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> importSales() => task(() async {
    final file = await const LocalStatementPicker().pick();
    if (file == null) return;
    if (!file.name.toLowerCase().endsWith('.csv')) {
      throw const FormatException(
        'Customer sales imports require CSV, not PDF.',
      );
    }
    repo.importSales(file.bytes);
    notice = 'Sales imported. Repeated Sale IDs are not counted twice.';
  });
  Future<void> merge() async {
    if (sourceId == null || targetId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge customer identities?'),
        content: const Text(
          'Payments will be combined under the destination identity. Original transactions remain unchanged. You can undo this merge.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await task(() => repo.merge(sourceId!, targetId!));
    }
  }

  void contact(CustomerStats customer) => showDialog<void>(
    context: context,
    builder: (_) => _ContactDialog(customer: customer, template: repo.template),
  );
  Widget section(String title, List<Widget> children) => GlassPanel(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget metric(String title, String value) => SizedBox(
    width: 210,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (storageFailed) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)),
      );
    }
    if (!widget.controller.paid) {
      return const Center(
        child: Text(
          'Customer performance is a paid demo tool. Enable Preview paid plan in Settings. No payment is collected.',
        ),
      );
    }
    final dropped = results.dropped;
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Customer Performance and Drop-off',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Your data stays on this device'),
          const SizedBox(height: 12),
          section('Data and analysis date', [
            const Text(
              'Received customer payments from all saved supported-statement imports are deduplicated automatically. Import sales CSVs or use fabricated data while additional source formats are being added.',
            ),
            const Text(
              'Sales CSV columns: Date, Customer Name, Phone, Amount, Sale ID (optional). Amounts are positive KES. Do not import the same sale through both sources: cross-source matching is not guessed.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : importSales,
                  child: const Text('Import sales CSV'),
                ),
                FilledButton.tonal(
                  onPressed: busy
                      ? null
                      : () => task(() => repo.addSamples(asOf)),
                  child: const Text('Use fabricated customers'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => task(() {
                          repo = CustomerRepository(widget.controller.store);
                        }),
                  child: const Text('Refresh saved payments'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: kenyaDay(asOf),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2200),
                          );
                          if (d != null && mounted) {
                            await task(
                              () => asOf = DateTime.utc(
                                d.year,
                                d.month,
                                d.day,
                                12,
                              ),
                            );
                          }
                        },
                  child: Text('As of ${formatKenyaDate(asOf)}'),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (notice != null) Text(notice!),
          ]),
          section('Customer summary', [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                metric('Customers', '${results.customers.length}'),
                metric('Received customer payments', formatKes(results.total)),
                metric('At Risk / Lost', '${dropped.length}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your top ${results.customers.length < 5 ? results.customers.length : 5} clients bring ${(results.topFiveShare * 100).toStringAsFixed(1)}% of received customer income.',
            ),
            if (results.futureExcluded > 0)
              Text(
                '${results.futureExcluded} future-dated payments excluded at this analysis date.',
              ),
            const Text(
              'RFM scores run from 1 (lower) to 5 (higher). Drop-off flags use each customer’s median gap between distinct purchase dates. One-date histories have no personalised drop-off estimate.',
            ),
            const Text(
              'Name-only identities and masked phone numbers need review. Exact normalised names are grouped; use merges for confirmed duplicates.',
            ),
          ]),
          section('Ranked clients · total spent', [
            if (results.customers.isEmpty)
              const Text(
                'No customer payments yet. Load the fabricated customer sample to test without a statement.',
              )
            else
              _CustomerTable(customers: results.customers, contact: contact),
          ]),
          section('At Risk / Recently Dropped', [
            const Text(
              'Sorted by most recent last purchase. Historical monthly worth estimates total spend divided by the active purchase span, with a one-month minimum.',
            ),
            if (dropped.isEmpty)
              const Text(
                'No personalised drop-off flags at this analysis date.',
              )
            else
              _CustomerTable(
                customers: dropped,
                contact: contact,
                dropped: true,
              ),
          ]),
          section('Monthly retention / churn', [
            const Text(
              'Of last month’s active customers, retained means paid again this month; churn means no payment this month. The current month is incomplete. These activity rates differ from personalised drop-off flags. Showing up to 24 months.',
            ),
            const SizedBox(height: 12),
            for (final month in results.months)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${month.month.month.toString().padLeft(2, '0')}/${month.month.year} · ${month.active} active · ${month.newCustomers} new · retention ${month.retention == null ? '—' : '${(month.retention! * 100).toStringAsFixed(0)}%'} / churn ${month.churn == null ? '—' : '${(month.churn! * 100).toStringAsFixed(0)}%'}',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: month.retention ?? 0,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${month.retained}/${month.previous}'),
                      ],
                    ),
                  ],
                ),
              ),
          ]),
          section('Merge duplicate identities', [
            const Text(
              'Choose two confirmed identities. Balances and original financial statements are not changed. Names alone do not prove two people are the same.',
            ),
            const SizedBox(height: 12),
            if (results.customers.length >= 2)
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'source:$sourceId:${results.customers.length}',
                    ),
                    initialValue: sourceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Merge this identity',
                    ),
                    items: [
                      for (final c in results.customers)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c.name} · ${c.phone ?? 'name only'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => sourceId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'target:$targetId:${results.customers.length}',
                    ),
                    initialValue: targetId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Keep this destination identity',
                    ),
                    items: [
                      for (final c in results.customers)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c.name} · ${c.phone ?? 'name only'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => targetId = v),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed:
                      busy ||
                          sourceId == null ||
                          targetId == null ||
                          sourceId == targetId
                      ? null
                      : merge,
                  child: const Text('Merge identities'),
                ),
                OutlinedButton(
                  onPressed: busy || repo.history.isEmpty
                      ? null
                      : () => task(repo.undoMerge),
                  child: const Text('Undo last merge'),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CustomerTable extends StatefulWidget {
  const _CustomerTable({
    required this.customers,
    required this.contact,
    this.dropped = false,
  });
  final List<CustomerStats> customers;
  final void Function(CustomerStats) contact;
  final bool dropped;
  @override
  State<_CustomerTable> createState() => _CustomerTableState();
}

class _CustomerTableState extends State<_CustomerTable> {
  late _CustomerSource source;
  @override
  void initState() {
    super.initState();
    source = _CustomerSource(widget.customers, widget.contact, widget.dropped);
  }

  @override
  void didUpdateWidget(covariant _CustomerTable old) {
    super.didUpdateWidget(old);
    source.dispose();
    source = _CustomerSource(widget.customers, widget.contact, widget.dropped);
  }

  @override
  void dispose() {
    source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PaginatedDataTable(
    key: ValueKey(widget.customers),
    columns: [
      for (final label in [
        'Customer',
        'Segment',
        'Total spent',
        'Payments',
        'Average payment',
        'First payment',
        'Last payment',
        'Days since',
        'Median gap (days)',
        'R / F / M',
        if (widget.dropped) 'Prior monthly worth',
        'Contact',
      ])
        DataColumn(label: Text(label)),
    ],
    source: source,
    rowsPerPage: 10,
    availableRowsPerPage: const [10],
    showCheckboxColumn: false,
  );
}

class _CustomerSource extends DataTableSource {
  _CustomerSource(this.rows, this.contact, this.dropped);
  final List<CustomerStats> rows;
  final void Function(CustomerStats) contact;
  final bool dropped;
  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final c = rows[index];
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 160,
            child: Text(
              '${c.name}\n${c.phone ?? 'No full phone'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        for (final v in [
          c.segment.label,
          formatKes(c.total),
          '${c.count}',
          formatKes(c.average),
          formatKenyaDate(c.first),
          formatKenyaDate(c.last),
          '${c.daysSince}',
          c.gap?.toStringAsFixed(1) ?? 'Insufficient history',
          '${c.r} / ${c.f} / ${c.m}',
          if (dropped) formatKes(c.priorMonthly),
        ])
          DataCell(Text(v)),
        DataCell(
          TextButton(
            onPressed: c.phone == null ? null : () => contact(c),
            child: const Text('Contact this customer'),
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => rows.length;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({required this.customer, required this.template});
  final CustomerStats customer;
  final String template;
  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final TextEditingController message;
  String? status;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    message = TextEditingController(
      text: widget.template.replaceAll('{name}', widget.customer.name),
    );
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> open(bool sms) async {
    setState(() => busy = true);
    try {
      final uri = customerContactUri(
        widget.customer.phone!,
        message: sms ? message.text : null,
      );
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (mounted) {
        setState(
          () => status = launched
              ? 'Opened your device app. Review before calling or sending.'
              : 'No app is configured for this action. Use a phone/SMS-capable device.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'No calling/SMS app could be opened on this device.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Contact this customer'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('${widget.customer.name}\n${widget.customer.phone}'),
            const SizedBox(height: 12),
            const Text(
              'Opens your device’s dialler or SMS composer. HESABU does not place a call or send a message automatically. Fabricated sample numbers must not be contacted.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: message,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Edit SMS message'),
            ),
            if (status != null) Text(status!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      OutlinedButton(
        onPressed: busy ? null : () => open(false),
        child: const Text('Open phone'),
      ),
      FilledButton(
        onPressed: busy ? null : () => open(true),
        child: const Text('Open SMS'),
      ),
    ],
  );
}
