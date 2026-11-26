import 'dart:typed_data';

import '../mpesa/models.dart';
import '../mpesa/statement_parser.dart';
import 'statement_provider.dart';

class MpesaStatementAdapter implements StatementAdapter {
  const MpesaStatementAdapter();
  @override
  StatementProvider get provider => StatementProvider.mpesa;
  @override
  ParsedStatement parseCsv(Uint8List bytes) =>
      const MpesaStatementParser().parseCsv(bytes);
  @override
  ParsedStatement parsePdfText(String text) =>
      const MpesaStatementParser().parsePdfText(text);
}
