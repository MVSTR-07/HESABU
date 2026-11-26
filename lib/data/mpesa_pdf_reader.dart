import 'dart:typed_data';

import 'package:pdfrx_engine/pdfrx_engine.dart';

import '../core/mpesa/models.dart';
import '../core/mpesa/pdf_table_layout.dart';
import '../core/statements/statement_provider.dart';
import 'pdf_table_rules.dart';

abstract interface class PdfTextReader {
  Future<String> read(Uint8List bytes, {String? password});
}

/// Only openData is used: no URL, telemetry, decrypted file or document cache.
/// PDFium binaries are bundled at build time. The password stays in memory.
class LocalPdfTextReader implements PdfTextReader {
  LocalPdfTextReader({required this.cachePath});
  final String? cachePath;
  static Future<void>? _initialization;

  @override
  Future<String> read(Uint8List bytes, {String? password}) async {
    return _read(bytes, password: password, strictMpesaLayout: true);
  }

  /// Bank and wallet adapters have their own row layouts. They still use the
  /// same local PDFium extraction, but must not be rejected by M-Pesa's table
  /// geometry rules before their adapter can inspect the text.
  Future<String> readForProvider(
    Uint8List bytes, {
    String? password,
    required StatementProvider provider,
  }) => _read(
    bytes,
    password: password,
    strictMpesaLayout: provider == StatementProvider.mpesa,
  );

  Future<String> _read(
    Uint8List bytes, {
    String? password,
    required bool strictMpesaLayout,
  }) async {
    if (bytes.isEmpty) {
      throw const StatementImportException('The selected file is empty.');
    }
    if (bytes.length < 8 ||
        !String.fromCharCodes(bytes.take(5)).startsWith('%PDF-')) {
      throw const StatementImportException(
        'The PDF is corrupt or is not a PDF file. Export a fresh statement.',
      );
    }
    PdfDocument? document;
    try {
      Pdfrx.debugLazyLoading = false;
      Pdfrx.createHttpClient = () =>
          throw StateError('PDF network access is disabled.');
      Pdfrx.cacheDirectoryPath = cachePath;
      await (_initialization ??= pdfrxInitialize(tmpPath: cachePath));
      var supplied = false;
      document = await PdfDocument.openData(
        bytes,
        sourceName: 'local-statement',
        passwordProvider: () {
          if (supplied || password == null || password.isEmpty) return null;
          supplied = true;
          return password;
        },
      );
      if (document.pages.length > 500) {
        throw const StatementImportException(
          'PDF exceeds 500 pages. Import a shorter date range.',
        );
      }
      final text = StringBuffer();
      final table = PdfStatementTable();
      final layoutProblems = <String>[];
      for (final page in document.pages) {
        final extracted = await page.loadText();
        text.writeln(extracted?.fullText ?? '');
        if (extracted != null && strictMpesaLayout) {
          final words = positionedPdfWords(extracted);
          try {
            final rules = await readStatementRules(document, page.pageNumber);
            table.addPage(words, rules: rules);
          } on StatementImportException catch (error) {
            // These messages contain only fixed labels and ordinal positions.
            // Scan remaining pages before reporting; NEVER save a partial PDF.
            layoutProblems.add(error.message);
          }
        }
        if (text.length > 8 * 1024 * 1024) {
          throw const StatementImportException(
            'PDF text is too large. Import a shorter date range.',
          );
        }
      }
      if (layoutProblems.isNotEmpty) {
        throw StatementImportException(
          summarisePdfLayoutProblems(document.pages.length, layoutProblems),
        );
      }
      return table.foundTable ? table.encode() : text.toString();
    } on PdfPasswordException {
      throw const StatementImportException(
        'The PDF password is incorrect or missing. Select the file again and retry.',
      );
    } on StatementImportException {
      rethrow;
    } catch (_) {
      // Do not expose native exceptions: they may contain user data or secrets.
      throw const StatementImportException(
        'The PDF could not be opened. It may be corrupt or use unsupported protection. Export a fresh PDF or CSV.',
      );
    } finally {
      await document?.dispose();
    }
  }
}

/// Group the whole-document scan without including extracted business text.
String summarisePdfLayoutProblems(int pages, List<String> problems) {
  final counts = <String, int>{};
  final representatives = <String, String>{};
  for (final problem in problems) {
    final code =
        RegExp(r'\[([A-Z_]+)\]').firstMatch(problem)?.group(1) ?? 'LAYOUT';
    final missing = RegExp(r'Missing columns: ([^.]+)\.')
        .firstMatch(problem)
        ?.group(1);
    final conflicting = RegExp(r'Conflicting columns: ([^.]+)\.')
        .firstMatch(problem)
        ?.group(1);
    final key =
        '$code${missing == null ? '' : ' (missing $missing; conflicting ${conflicting ?? 'none'})'}';
    counts[key] = (counts[key] ?? 0) + 1;
    representatives.putIfAbsent(key, () => problem);
  }
  final summary = counts.entries
      .map((e) => '${e.key}: ${e.value} page(s)')
      .join('; ');
  final examples = representatives.values.take(5).join('\n\n');
  return 'Checked all $pages PDF pages locally. ${problems.length} page(s) have layout failures ($summary). No partial import was saved.\n\n$examples${representatives.length > 5 ? '\n\nAdditional issue types are counted above; examples limited to five.' : ''}';
}
