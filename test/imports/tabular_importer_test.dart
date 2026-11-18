import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/core/imports/tabular_importer.dart';
import 'package:hesabu/core/sample_data.dart';

void main() {
  const importer = TabularImporter();

  test('cleans fabricated sales CSV and reports invalid rows', () {
    final preview = importer.preview(
      generateSampleSalesImportCsv(),
      'sample.csv',
    );
    expect(preview.target, ImportTarget.sales);
    expect(preview.rows, hasLength(2));
    expect(preview.rows.first.description, 'Maize flour 2kg');
    expect(preview.rows.first.amountMinor, 36000);
    expect(preview.rows.first.unitPriceMinor, 18000);
    expect(preview.errors, hasLength(1));
  });

  test('reads a fabricated Excel sheet in memory', () {
    final preview = importer.preview(
      generateSampleSalesImportXlsx(),
      'fabricated.xlsx',
    );
    expect(preview.rows, hasLength(2));
    expect(preview.rows.first.amountMinor, 36000);
    expect(preview.rows.first.unitPriceMinor, 18000);
  });

  test('rejects empty, malformed, unsupported and oversized sources', () {
    expect(
      () => importer.preview(Uint8List(0), 'empty.csv'),
      throwsFormatException,
    );
    expect(
      () => importer.preview(
        Uint8List.fromList(utf8.encode('date,amount\n')),
        'empty.csv',
      ),
      throwsFormatException,
    );
    expect(
      () => importer.preview(Uint8List.fromList([1, 2, 3]), 'wrong.pdf'),
      throwsFormatException,
    );
    expect(
      () => importer.preview(
        Uint8List(TabularImporter.maxBytes + 1),
        'large.csv',
      ),
      throwsFormatException,
    );
  });
}
