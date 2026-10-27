import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bizlens/core/mpesa/analyser.dart';
import 'package:bizlens/core/mpesa/models.dart';
import 'package:bizlens/core/mpesa/sample_column_pdf_bytes.dart';
import 'package:bizlens/core/mpesa/statement_parser.dart';
import 'package:bizlens/core/sample_data.dart';
import 'package:bizlens/data/mpesa_pdf_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:bizlens/data/pdf_table_rules.dart';
import 'package:bizlens/core/mpesa/ruled_statement_table.dart';

void main() {
  test('whole-document diagnostics group failures across 157 pages', () {
    final message = summarisePdfLayoutProblems(
      157,
      List.generate(
        12,
        (i) =>
            'PDF layout diagnostic [ROW_CELLS]: page ${i + 1}, row 1. Missing columns: Details.',
      ),
    );
    expect(message, contains('Checked all 157 PDF pages locally'));
    expect(
      message,
      contains('ROW_CELLS (missing Details; conflicting none): 12 page(s)'),
    );
    expect(message, contains('page 1, row 1'));
    expect(message, isNot(contains('page 6, row 1')));
    expect(message, contains('No partial import was saved'));
    final mixed = summarisePdfLayoutProblems(157, [
      for (var i = 0; i < 10; i++)
        'PDF layout diagnostic [ROW_CELLS]: page ${i + 1}. Missing columns: Details.',
      'PDF layout diagnostic [ROW_CELLS]: page 150. Missing columns: Balance.',
    ]);
    expect(mixed, contains('missing Balance'));
    expect(mixed, contains('page 150'));
  });
  late Directory directory;
  late LocalPdfTextReader reader;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'bizlens-fabricated-pdf-test-',
    );
    reader = LocalPdfTextReader(cachePath: directory.path);
  });
  tearDownAll(() async {
    await directory.delete(recursive: true);
  });

  test(
    'real protected PDF decrypts in memory and matches CSV totals',
    () async {
      final bytes = generateSampleMpesaPdf();
      expect(bytes, isNotEmpty);
      final text = await reader.read(bytes, password: sampleMpesaPassword);
      final pdf = const MpesaStatementParser().parsePdfText(text);
      final csv = const MpesaStatementParser().parseCsv(
        generateSampleMpesaCsv(),
      );
      expect(pdf.transactions.length, 23);
      for (var i = 0; i < pdf.transactions.length; i++) {
        expect(
          pdf.transactions[i].fingerprint,
          csv.transactions[i].fingerprint,
        );
      }
      final result = const MpesaAnalyser().analyse(pdf.transactions);
      expect(result.moneyIn, 26621000);
      expect(result.moneyOut, 1992700);
      expect(result.fulizaCost, 7000);
      expect(result.duplicateRows.length, 1);
      expect(
        await directory.list(recursive: true).isEmpty,
        isTrue,
        reason: 'PDF extraction must not cache a plaintext/decrypted document.',
      );
    },
  );

  test('wrong and missing passwords return safe password errors', () async {
    for (final password in ['wrong-fabricated-password', null, '']) {
      await expectLater(
        reader.read(generateSampleMpesaPdf(), password: password),
        throwsA(
          isA<StatementImportException>().having(
            (e) => e.message,
            'safe error',
            allOf(
              contains('password'),
              isNot(contains('wrong-fabricated-password')),
            ),
          ),
        ),
      );
    }
  });

  test(
    'portrait columns preserve blank amounts, wraps and repeated page headers',
    () async {
      final text = await reader.read(
        Uint8List.fromList(base64Decode(sampleMpesaColumnPdfBase64)),
        password: sampleMpesaPassword,
      );
      final parsed = const MpesaStatementParser().parsePdfText(text);
      final csv = const MpesaStatementParser().parseCsv(
        generateSampleMpesaCsv(),
      );
      expect(parsed.transactions.length, csv.transactions.length);
      for (var i = 0; i < csv.transactions.length; i++) {
        expect(
          parsed.transactions[i].fingerprint,
          csv.transactions[i].fingerprint,
        );
      }
    },
  );

  test(
    'empty, wrong-format and corrupt PDFs never escape as native errors',
    () async {
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList(utf8.encode('not a PDF')),
        Uint8List.fromList(
          utf8.encode('%PDF-1.7\ncorrupt fabricated fixture\n%%EOF'),
        ),
      ]) {
        await expectLater(
          reader.read(bytes),
          throwsA(isA<StatementImportException>()),
        );
      }
    },
  );
  test('native protected fixture exposes a physical seven-column grid on both pages', () async {
    final bytes = Uint8List.fromList(base64Decode(sampleMpesaColumnPdfBase64));
    await reader.read(bytes, password: sampleMpesaPassword);
    final doc = await PdfDocument.openData(
      bytes,
      passwordProvider: () => sampleMpesaPassword,
    );
    try {
      for (final page in doc.pages) {
        final raw = await page.loadText();
        final rules = await readStatementRules(doc, page.pageNumber);
        final cells = RuledStatementTable().extract(
          positionedPdfWords(raw!),
          rules,
          page: page.pageNumber,
        );
        expect(cells, isNotNull);
        expect(cells!.length, page.pageNumber == 1 ? 12 : 11);
      }
    } finally {
      await doc.dispose();
    }
  });
}
