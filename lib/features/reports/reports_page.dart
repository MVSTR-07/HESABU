import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/mpesa/models.dart';
import '../../core/reports/consolidated_report.dart';
import '../../core/reports/report_generator.dart';
import '../../data/operations_repository.dart';
import '../operations/operations_widgets.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _busy = false;
  String? _message;

  (OperationsRepository, DateTime, DateTime) _period() {
    final repository = OperationsRepository(widget.controller.store);
    final today = DateTime.now().toUtc().add(const Duration(hours: 3));
    return (
      repository,
      DateTime.utc(today.year, 1, 1),
      DateTime.utc(today.year, today.month, today.day),
    );
  }

  Future<void> _save({required bool asPdf}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final (repository, from, through) = _period();
      final summary = repository.analyseProfitAndLoss(
        from: from,
        through: through,
      );
      final balances = repository.obligations();
      final statements = widget.controller.store
          .listMpesaStatements()
          .map(
            (summary) => widget.controller.store.loadMpesaStatement(summary.id),
          )
          .whereType<StoredStatement>()
          .toList();
      final report = const ConsolidatedReportBuilder().build(
        profitAndLoss: summary,
        statements: statements,
        obligations: balances,
      );
      final generator = const ReportGenerator();
      final bytes = asPdf
          ? await generator.consolidatedPdf(report)
          : generator.consolidatedXlsx(report);
      final saved = await FileSaver.instance.saveAs(
        name: 'hesabu-business-report-${through.year}',
        bytes: bytes,
        fileExtension: asPdf ? 'pdf' : 'xlsx',
        mimeType: asPdf ? MimeType.pdf : MimeType.microsoftExcel,
        dialogTitle: 'Save HESABU report',
      );
      if (!mounted) return;
      setState(
        () => _message = saved == null
            ? 'Export cancelled. No report was saved.'
            : 'Report saved to the location you selected.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Report could not be created or saved. Your local records were not changed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = OperationsRepository(widget.controller.store);
    final rows = repository.obligations();
    final open = rows.where((row) => !row.isSettled).length;
    return OperationsPageFrame(
      title: 'Export reports',
      subtitle: 'Create a local visual year-to-date report from saved business results.',
      actions: [
        FilledButton.icon(
          onPressed: _busy ? null : () => _save(asPdf: true),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Save PDF'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _save(asPdf: false),
          icon: const Icon(Icons.table_view_outlined),
          label: const Text('Save Excel'),
        ),
      ],
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          OperationsSection(title: 'Export status', child: Text(_message!)),
        OperationsSection(
          title: 'Report contents',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The report uses local results only and opens the device save dialog. It includes key sales/expense figures, M-Pesa cash movement, visual charts, review flags and open balances. Raw statement rows are not included by default.',
              ),
              const SizedBox(height: 8),
              Text('$open open balance records will be included.'),
            ],
          ),
        ),
        const OperationsSection(
          title: 'Accounting basis',
          child: Text(
            'Operating surplus is recorded sales less recorded expenses. The export does not claim to include stock cost, tax or unrecorded activity. Review the report before using it for formal accounts.',
          ),
        ),
        const OperationsSection(
          title: 'Local privacy',
          child: Text(
            'HESABU builds the report in memory. It does not upload records or keep an extra cached copy. Choose where to save the exported report.',
          ),
        ),
      ],
    );
  }
}
