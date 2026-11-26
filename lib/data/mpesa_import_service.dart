import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/mpesa/analyser.dart';
import '../core/mpesa/classifier.dart';
import '../core/mpesa/models.dart';
import '../core/mpesa/ruled_statement_table.dart';
import '../core/statements/statement_adapter_registry.dart';
import '../core/statements/statement_provider.dart';
import 'local_store.dart';
import 'mpesa_pdf_reader.dart';

class MpesaImportService {
  MpesaImportService(this.store, {PdfTextReader? pdfReader})
    : _pdfReader =
          pdfReader ?? LocalPdfTextReader(cachePath: store.privateCachePath);
  final LocalStore store;
  final PdfTextReader _pdfReader;
  static const maxBytes = 25 * 1024 * 1024;

  Future<StoredStatement> importBytes(
    Uint8List bytes, {
    required String format,
    required String label,
    String? password,
    StatementProvider provider = StatementProvider.mpesa,
    AnomalyThresholds thresholds = const AnomalyThresholds(),
  }) async {
    if (bytes.isEmpty) {
      throw const StatementImportException('The selected file is empty.');
    }
    if (bytes.length > maxBytes) {
      throw const StatementImportException(
        'File exceeds 25 MB. Import a shorter statement.',
      );
    }
    thresholds.validate();
    ParsedStatement parsed;
    if (format == 'csv') {
      parsed = await _parseCsvOffThreadFor(bytes, provider);
    } else if (format == 'pdf') {
      final reader = _pdfReader;
      final text = reader is LocalPdfTextReader
          ? await reader.readForProvider(
              bytes,
              password: password,
              provider: provider,
            )
          : await _pdfReader.read(bytes, password: password);
      parsed = await _parsePdfTextOffThreadFor(text, provider);
    } else {
      throw const StatementImportException(
        'Choose a supported financial-statement PDF or CSV file.',
      );
    }
    final transactions = parsed.transactions
        .map(const MpesaClassifier().classify)
        .toList();
    final results = await _analyseOffThread(transactions, thresholds);
    final unknown = transactions
        .where((v) => v.type == MpesaType.unknown)
        .length;
    final statement = StoredStatement(
      id: 0,
      label: label,
      format: format,
      importedAt: DateTime.now().toUtc(),
      transactions: transactions,
      results: results,
      warnings: [
        ...parsed.warnings,
        if (unknown > 0)
          '$unknown transaction(s) are unclassified. Review the transaction table.',
        if (transactions.any(
          (v) => v.details == RuledStatementTable.unavailableDescription,
        ))
          'Some description cells have no extractable text. Their financial cells were retained and marked unclassified; review these rows before relying on category or customer totals.',
        'Cash movement includes loan principal and reversals; it is not sales or profit.',
        'Fees include identified Fuliza costs. Bundled or unspecified charges are not guessed.',
      ],
    );
    final hash = sha256.convert(bytes).toString();
    final id = store.saveMpesaStatement(statement, bytes, hash);
    return store.loadMpesaStatement(id)!;
  }

  Future<StoredStatement> reanalyse(
    StoredStatement statement,
    AnomalyThresholds thresholds,
  ) async {
    thresholds.validate();
    final txs = statement.transactions;
    final results = await _analyseOffThread(txs, thresholds);
    store.saveMpesaResults(statement.id, results);
    return store.loadMpesaStatement(statement.id)!;
  }
}

// Keep isolate closures outside the service: no SQLite handles, UI state or PDF
// password can accidentally enter an isolate's captured instance context.
Future<ParsedStatement> _parseCsvOffThreadFor(
  Uint8List bytes,
  StatementProvider provider,
) => Isolate.run(
  () => const StatementAdapterRegistry().adapterFor(provider).parseCsv(bytes),
);
Future<ParsedStatement> _parsePdfTextOffThreadFor(
  String text,
  StatementProvider provider,
) => Isolate.run(
  () =>
      const StatementAdapterRegistry().adapterFor(provider).parsePdfText(text),
);
Future<MpesaResults> _analyseOffThread(
  List<MpesaTransaction> txs,
  AnomalyThresholds thresholds,
) => Isolate.run(
  () => const MpesaAnalyser().analyse(txs, thresholds: thresholds),
);
