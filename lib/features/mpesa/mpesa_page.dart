import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/mpesa/models.dart';
import '../../core/mpesa/statement_parser.dart' show parseMoney;
import '../../core/sample_data.dart';
import '../../data/local_statement_picker.dart';
import '../../data/mpesa_import_service.dart';
import '../../ui/formatters.dart';
import '../../ui/shared.dart';
import 'mpesa_charts.dart';
import 'mpesa_tables.dart';
import 'password_dialog.dart';

class MpesaPage extends StatefulWidget {
  const MpesaPage({
    required this.controller,
    this.picker,
    this.service,
    this.importMode = true,
    super.key,
  });
  final AppController controller;
  final Future<SelectedStatement?> Function()? picker;
  final MpesaImportService? service;

  /// Import mode is shown from Workspaces. Tool mode is analysis-only.
  final bool importMode;
  @override
  State<MpesaPage> createState() => _MpesaPageState();
}

class _MpesaPageState extends State<MpesaPage> {
  late MpesaImportService _service;
  StoredStatement? _statement;
  List<StatementSummary> _history = [];
  String? _error;
  bool _busy = false;
  String _period = 'Day';
  AnomalyThresholds _thresholds = const AnomalyThresholds();
  final _large = TextEditingController(),
      _spike = TextEditingController(),
      _minimum = TextEditingController(),
      _baseline = TextEditingController();
  TransactionSource? _transactions;
  PeriodSource? _periods;
  int _anomalyPage = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MpesaImportService(widget.controller.store);
    try {
      final config = widget.controller.store.readSetting('mpesa_thresholds');
      if (config != null) {
        _thresholds = AnomalyThresholds.fromJson(
          jsonDecode(config) as Map<String, dynamic>,
        );
        _thresholds.validate();
      }
      _history = widget.controller.store.listMpesaStatements();
      if (_history.isNotEmpty) {
        _setStatement(
          widget.controller.store.loadMpesaStatement(_history.first.id)!,
        );
      }
    } catch (_) {
      _error = 'Saved M-Pesa data could not be loaded. Restart the app or clear imports from Settings.';
    }
    _fillThresholds();
  }

  void _fillThresholds() {
    _large.text = (_thresholds.largeAmount / 100).toStringAsFixed(2);
    _spike.text = _thresholds.spikeMultiplier.toString();
    _minimum.text = (_thresholds.minimumSpikeAmount / 100).toStringAsFixed(2);
    _baseline.text = '${_thresholds.minimumBaseline}';
  }

  List<CashPeriod> get _selectedPeriods => switch (_period) {
    'Week' => _statement?.results.weekly ?? [],
    'Month' => _statement?.results.monthly ?? [],
    _ => _statement?.results.daily ?? [],
  };

  void _setStatement(StoredStatement value) {
    _statement = value;
    _thresholds = value.results.thresholds;
    _transactions?.dispose();
    _transactions = TransactionSource(value);
    _periods?.dispose();
    _periods = PeriodSource(_selectedPeriods);
    _anomalyPage = 0;
    _fillThresholds();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || widget.controller.busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.controller.setImportBusy(true);
    try {
      await action();
    } on StatementImportException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      // Never log raw errors, file paths, PDF passwords or statement contents.
      if (mounted) {
        setState(
          () => _error = 'This operation could not finish. Check local disk space and file access, then try again. No data was sent.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.controller.setImportBusy(false);
    }
  }

  Future<void> _import(
    Uint8List bytes,
    String format,
    String label, {
    bool fabricated = false,
  }) async {
    if (bytes.isEmpty) {
      throw const StatementImportException('The selected file is empty.');
    }
    if (!['csv', 'pdf'].contains(format)) {
      throw const StatementImportException(
        'Choose a supported financial-statement PDF or CSV file. M-Pesa is the first supported source.',
      );
    }
    String? password;
    try {
      if (format == 'pdf') {
        if (!mounted) return;
        password = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => StatementPasswordDialog(fabricated: fabricated),
        );
        if (password == null) return;
      }
      final value = await _service.importBytes(
        bytes,
        format: format,
        label: label,
        password: password,
        thresholds: _thresholds,
      );
      if (!mounted) return;
      setState(() {
        _setStatement(value);
        _history = widget.controller.store.listMpesaStatements();
      });
    } finally {
      password = null;
    }
  }

  Future<void> _pick() => _run(() async {
    final file =
        await (widget.picker?.call() ?? const LocalStatementPicker().pick());
    if (file != null) {
      await _import(
        file.bytes,
        file.name.split('.').last.toLowerCase(),
        file.name,
      );
    }
  });

  Future<void> _applyThresholds() => _run(() async {
    AnomalyThresholds thresholds;
    try {
      thresholds = AnomalyThresholds(
        largeAmount: parseMoney(_large.text, row: 0),
        spikeMultiplier: double.parse(_spike.text),
        minimumSpikeAmount: parseMoney(_minimum.text, row: 0),
        minimumBaseline: int.parse(_baseline.text),
      );
      thresholds.validate();
    } catch (_) {
      throw const StatementImportException(
        'Check thresholds: positive large-payment amount, multiplier above 1, non-negative minimum spike amount, and 3–1000 baseline payments.',
      );
    }
    if (_statement != null) {
      final value = await _service.reanalyse(_statement!, thresholds);
      if (mounted) setState(() => _setStatement(value));
    }
    widget.controller.store.writeSetting(
      'mpesa_thresholds',
      jsonEncode(thresholds.toJson()),
    );
    _thresholds = thresholds;
  });

  @override
  void dispose() {
    for (final c in [_large, _spike, _minimum, _baseline]) {
      c.dispose();
    }
    _transactions?.dispose();
    _periods?.dispose();
    super.dispose();
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );

  Widget _metric(String label, String value) => SizedBox(
    width: 210,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ContentWidth(
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.importMode
              ? 'Import financial documents'
              : 'Financial Statement Analyser',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Your data stays on this device'),
        const SizedBox(height: 16),
        if (widget.importMode) ...[
          _section(
            'Import a statement',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a local CSV or text-based PDF (up to 25 MB). Protected PDFs need a password. Sources and results are encrypted locally; passwords are never saved.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose PDF / CSV'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _import(
                                generateSampleMpesaCsv(),
                                'csv',
                                'Fabricated mobile-money CSV',
                              ),
                            ),
                      child: const Text('Use fabricated CSV'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _import(
                                generateSampleMpesaPdf(),
                                'pdf',
                                'Fabricated mobile-money PDF',
                                fabricated: true,
                              ),
                            ),
                      child: const Text('Use protected sample PDF'),
                    ),
                  ],
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (_history.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: DropdownButtonFormField<int>(
                      key: ValueKey(
                        'saved-${_statement?.id}-${_history.length}',
                      ),
                      initialValue: _statement?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Saved statements',
                      ),
                      items: _history
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.label} · ${formatKenyaDate(s.importedAt)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (id) {
                              if (id != null) {
                                _run(() async {
                                  final value = widget.controller.store
                                      .loadMpesaStatement(id);
                                  if (value != null && mounted) {
                                    setState(() => _setStatement(value));
                                  }
                                });
                              }
                            },
                    ),
                  ),
              ],
            ),
          ),
        ],
        _section(
          'Anomaly thresholds',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exact duplicate rows are flagged and excluded from totals. A shared receipt with different details is retained for review. Spikes compare against the other payments in the same direction.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final field in [
                    (_large, 'Large payment (KES)'),
                    (_spike, 'Spike multiplier'),
                    (_minimum, 'Minimum spike (KES)'),
                    (_baseline, 'Other payments needed'),
                  ])
                    SizedBox(
                      width: 210,
                      child: TextField(
                        controller: field.$1,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(labelText: field.$2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _busy ? null : _applyThresholds,
                child: const Text('Save thresholds & reanalyse'),
              ),
            ],
          ),
        ),
        if (_statement != null) ..._results(),
      ],
    ),
  );

  List<Widget> _results() {
    final s = _statement!, r = s.results;
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final days = List.generate(7, (i) => i)
      ..sort((a, b) => r.weekdays[b].compareTo(r.weekdays[a]));
    final hours = List.generate(24, (i) => i)
      ..sort((a, b) => r.hours[b].compareTo(r.hours[a]));
    return [
      _section(
        'Summary · ${s.label}',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _metric('Money in', formatKes(r.moneyIn)),
                _metric('Money out', formatKes(r.moneyOut)),
                _metric('Net movement', formatKes(r.net)),
                _metric('Identified fees paid', formatKes(r.fees)),
                _metric(
                  'Fuliza cost (included in fees)',
                  formatKes(r.fulizaCost),
                ),
                _metric(
                  'Completed rows / unique rows',
                  '${s.transactions.length} / ${r.uniqueCount}',
                ),
                _metric('Duplicate rows excluded', '${r.duplicateRows.length}'),
              ],
            ),
            const SizedBox(height: 12),
            for (final warning in s.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $warning'),
              ),
          ],
        ),
      ),
      _section(
        'Cash movement by period',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Group by'),
              items: [
                'Day',
                'Week',
                'Month',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _period = v;
                    _periods?.dispose();
                    _periods = PeriodSource(_selectedPeriods);
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            CashFlowChart(periods: _selectedPeriods),
            const Text(
              'Weeks start on Monday. All periods use Kenya time. Amounts exclude exact duplicates.',
            ),
            PaginatedDataTable(
              key: ValueKey('period-${s.id}-$_period-${r.thresholds.toJson()}'),
              rowsPerPage: 10,
              availableRowsPerPage: const [10],
              source: _periods!,
              columns: const [
                DataColumn(label: Text('Period start')),
                DataColumn(label: Text('Money in')),
                DataColumn(label: Text('Money out')),
                DataColumn(label: Text('Net')),
                DataColumn(label: Text('Count')),
              ],
            ),
          ],
        ),
      ),
      _section(
        'Busiest days and hours',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By number of unique completed transactions (not revenue).',
            ),
            for (final i in days.where((i) => r.weekdays[i] > 0))
              Text('${dayNames[i]}: ${r.weekdays[i]}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: hours
                  .where((i) => r.hours[i] > 0)
                  .map(
                    (i) => Text(
                      '${i.toString().padLeft(2, '0')}:00–${i.toString().padLeft(2, '0')}:59 · ${r.hours[i]}',
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
      _section(
        'Top 10 senders · customer receipts',
        RankingTable(parties: r.senders),
      ),
      _section(
        'Top 10 receivers · transfers, tills and agents',
        RankingTable(parties: r.receivers),
      ),
      _section('Balance trend', BalanceTrendChart(points: r.balances)),
      _section('Anomaly flags · ${r.anomalies.length}', _anomalies(s)),
      _section(
        'Normalised transactions',
        PaginatedDataTable(
          key: ValueKey('tx-${s.id}-${r.thresholds.toJson()}'),
          rowsPerPage: 10,
          availableRowsPerPage: const [10],
          source: _transactions!,
          dataRowMaxHeight: 96,
          columns: const [
            DataColumn(label: Text('Row')),
            DataColumn(label: Text('Kenya date / time')),
            DataColumn(label: Text('Receipt no.')),
            DataColumn(label: Text('Details')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Paid in')),
            DataColumn(label: Text('Withdrawn')),
            DataColumn(label: Text('Balance')),
          ],
        ),
      ),
    ];
  }

  Widget _anomalies(StoredStatement statement) {
    final flags = statement.results.anomalies;
    if (flags.isEmpty) {
      return const Text(
        'No flags under the current thresholds. This is not a guarantee of accuracy or fraud detection.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review flags against the original statement. A flag is a rule match, not a finding of fraud.',
        ),
        for (final flag in flags.skip(_anomalyPage * 20).take(20))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Row ${flag.row} · ${switch (flag.kind) {
                AnomalyKind.duplicate => 'Duplicate',
                AnomalyKind.receiptConflict => 'Shared receipt',
                AnomalyKind.spike => 'Unusual spike',
                AnomalyKind.largeOneOff => 'Large one-off',
              }}: ${flag.message}',
            ),
          ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: _anomalyPage > 0
                  ? () => setState(() => _anomalyPage--)
                  : null,
              child: const Text('Previous flags'),
            ),
            Text('Page ${_anomalyPage + 1} of ${(flags.length / 20).ceil()}'),
            TextButton(
              onPressed: (_anomalyPage + 1) * 20 < flags.length
                  ? () => setState(() => _anomalyPage++)
                  : null,
              child: const Text('Next flags'),
            ),
          ],
        ),
      ],
    );
  }
}
