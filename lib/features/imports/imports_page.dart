import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/imports/tabular_importer.dart';
import '../../core/sample_data.dart';
import '../../data/operations_repository.dart';
import '../operations/operations_widgets.dart';

class ImportsPage extends StatefulWidget {
  const ImportsPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<ImportsPage> createState() => _ImportsPageState();
}

class _ImportsPageState extends State<ImportsPage> {
  ImportPreview? _preview;
  String? _fileName;
  String? _message;
  ImportTarget? _target;

  void _loadFabricatedCsv() {
    try {
      final preview = const TabularImporter().preview(
        generateSampleSalesImportCsv(),
        'fabricated-sales.csv',
      );
      setState(() {
        _preview = preview;
        _target = preview.target;
        _fileName = 'Fabricated sales CSV';
        _message = 'Fabricated preview loaded. No file was read or written.';
      });
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  void _loadFabricatedXlsx() {
    try {
      final preview = const TabularImporter().preview(
        generateSampleSalesImportXlsx(),
        'fabricated-sales.xlsx',
      );
      setState(() {
        _preview = preview;
        _target = preview.target;
        _fileName = 'Fabricated sales Excel';
        _message = 'Fabricated workbook preview loaded locally.';
      });
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  Future<void> _chooseFile() async {
    try {
      const group = XTypeGroup(
        label: 'Business spreadsheet',
        extensions: ['csv', 'xlsx', 'xls'],
      );
      final file = await openFile(acceptedTypeGroups: [group]);
      if (file == null || !mounted) return;
      widget.controller.setImportBusy(true);
      final bytes = await file.readAsBytes();
      final preview = const TabularImporter().preview(bytes, file.name);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _target = preview.target;
        _fileName = file.name;
        _message = null;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'That file could not be read. Choose a CSV or Excel workbook and try again.',
        );
      }
    } finally {
      widget.controller.setImportBusy(false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null || _target == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import ${preview.rows.length} clean rows?'),
        content: Text(
          'Rows will be added to ${_target == ImportTarget.sales ? 'Sales' : 'Expenses'} in the encrypted local database. The selected source file is not copied or retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import locally'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    widget.controller.setImportBusy(true);
    try {
      final adjusted = ImportPreview(
        target: _target!,
        rows: preview.rows,
        errors: preview.errors,
        headers: preview.headers,
      );
      final count = OperationsRepository(widget.controller.store)
          .importRows(adjusted);
      if (mounted) {
        setState(() {
          _message =
              '$count rows imported to ${_target == ImportTarget.sales ? 'Sales' : 'Expenses'} on this device.';
          _preview = null;
          _fileName = null;
        });
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Import failed. No partial rows were saved.');
      }
    } finally {
      widget.controller.setImportBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) => OperationsPageFrame(
    title: 'Import and clean',
    subtitle: 'Review a local CSV or Excel sheet before adding clean sales or expense rows.',
    actions: [
      FilledButton.icon(
        onPressed: widget.controller.busy ? null : _chooseFile,
        icon: const Icon(Icons.file_open_outlined),
        label: const Text('Choose CSV / Excel'),
      ),
      OutlinedButton.icon(
        onPressed: widget.controller.busy ? null : _loadFabricatedCsv,
        icon: const Icon(Icons.science_outlined),
        label: const Text('Preview fabricated CSV'),
      ),
      OutlinedButton.icon(
        onPressed: widget.controller.busy ? null : _loadFabricatedXlsx,
        icon: const Icon(Icons.science_outlined),
        label: const Text('Preview fabricated Excel'),
      ),
      if (_preview != null)
        OutlinedButton.icon(
          onPressed: widget.controller.busy ? null : _import,
          icon: const Icon(Icons.check),
          label: const Text('Import clean rows'),
        ),
    ],
    children: [
      if (_message != null)
        OperationsSection(title: 'Import status', child: Text(_message!)),
      const OperationsSection(
        title: 'How cleaning works',
        child: Text(
          'HESABU reads the selected file in memory, detects common date, description, amount, quantity and party columns, then shows valid rows and any skipped rows. No source copy or temporary plaintext file is kept.',
        ),
      ),
      if (_preview case final preview?) ...[
        OperationsSection(
          title: 'Preview · ${_fileName ?? 'selected file'}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<ImportTarget>(
                initialValue: _target,
                decoration: const InputDecoration(
                  labelText: 'Import clean rows as',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ImportTarget.sales,
                    child: Text('Sales'),
                  ),
                  DropdownMenuItem(
                    value: ImportTarget.expenses,
                    child: Text('Expenses'),
                  ),
                ],
                onChanged: (value) => setState(() => _target = value),
              ),
              const SizedBox(height: 10),
              Text(
                '${preview.rows.length} clean rows · ${preview.errors.length} skipped rows',
              ),
              const SizedBox(height: 8),
              for (final row in preview.rows.take(20))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.description),
                  subtitle: Text(
                    '${row.date.day.toString().padLeft(2, '0')}/${row.date.month.toString().padLeft(2, '0')}/${row.date.year} · ${row.quantity} units${row.party.isEmpty ? '' : ' · ${row.party}'}',
                  ),
                  trailing: Text(
                    'KES ${(row.amountMinor / 100).toStringAsFixed(2)}',
                  ),
                ),
              if (preview.rows.length > 20)
                const Text('Showing first 20 clean rows.'),
              if (preview.errors.isNotEmpty) ...[
                const Divider(),
                const Text('Rows skipped during cleaning'),
                for (final error in preview.errors.take(20)) Text('• $error'),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}
