import 'dart:typed_data';

import '../mpesa/models.dart';
import 'statement_provider.dart';
import 'bank_statement_parser.dart';

class EquityStatementAdapter implements StatementAdapter {
  const EquityStatementAdapter();
  @override
  StatementProvider get provider => StatementProvider.equity;

  @override
  ParsedStatement parseCsv(Uint8List bytes) =>
      BankStatementParser(providerName: 'Equity').parseCsv(bytes);

  @override
  ParsedStatement parsePdfText(String text) {
    if (RegExp(
      r'no transactions for this period',
      caseSensitive: false,
    ).hasMatch(text)) {
      throw const StatementImportException(
        'This Equity statement contains no transactions for the selected period.',
      );
    }
    final lines = text.replaceAll('\r', '').split('\n');
    return BankStatementParser(providerName: 'Equity')
        .parsePdfRows(lines, rowPattern: _row);
  }
}

final _row = RegExp(
  r'^(?<date>\d{1,2}[-/]\w{3}[-/]\d{2,4}|\d{4}[-/]\d{2}[-/]\d{2})\s+(?<details>.*?)\s+(?<out>-?[\d,]+(?:\.\d{1,2})?|-)\s+(?<in>-?[\d,]+(?:\.\d{1,2})?|-)\s+(?<balance>-?[\d,]+(?:\.\d{1,2})?)\s*$',
  caseSensitive: false,
);
