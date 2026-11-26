import 'dart:typed_data';

import '../mpesa/models.dart';
import 'bank_statement_parser.dart';
import 'statement_provider.dart';

class NcbaLoopStatementAdapter implements StatementAdapter {
  const NcbaLoopStatementAdapter();
  @override
  StatementProvider get provider => StatementProvider.ncbaLoop;
  @override
  ParsedStatement parseCsv(Uint8List bytes) =>
      BankStatementParser(providerName: 'NCBA Loop').parseCsv(bytes);
  @override
  ParsedStatement parsePdfText(String text) =>
      BankStatementParser(providerName: 'NCBA Loop')
          .parsePdfBlocks(text.replaceAll('\r', ' '), blockStart: _blockStart);
}

final _blockStart = RegExp(
  r'(?<!\d)(\d{1,2}\s+[A-Za-z]{3}\s+\d{2,4})(?=\s)',
  caseSensitive: false,
);
