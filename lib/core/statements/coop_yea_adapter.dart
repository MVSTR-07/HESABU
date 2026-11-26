import 'dart:typed_data';

import '../mpesa/models.dart';
import 'bank_statement_parser.dart';
import 'statement_provider.dart';

class CoopYeaStatementAdapter implements StatementAdapter {
  const CoopYeaStatementAdapter();
  @override
  StatementProvider get provider => StatementProvider.coopYea;
  @override
  ParsedStatement parseCsv(Uint8List bytes) =>
      BankStatementParser(providerName: 'Co-op YEA').parseCsv(bytes);
  @override
  ParsedStatement parsePdfText(String text) =>
      BankStatementParser(providerName: 'Co-op YEA')
          .parsePdfBlocks(text.replaceAll('\r', ' '), blockStart: _blockStart);
}

final _blockStart = RegExp(
  r'(?<!\d)(\d{1,2}-[A-Za-z]{3}-\d{2,4})(?=\s)',
  caseSensitive: false,
);
