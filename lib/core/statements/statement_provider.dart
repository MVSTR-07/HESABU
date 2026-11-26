import 'dart:typed_data';

import '../mpesa/models.dart';

enum StatementProvider {
  equity,
  mpesa,
  ncbaLoop,
  coopYea;

  String get label => switch (this) {
    equity => 'Equity',
    mpesa => 'M-Pesa',
    ncbaLoop => 'NCBA Loop',
    coopYea => 'Co-op YEA',
  };

  String get description => switch (this) {
    equity => 'Equity bank statement',
    mpesa => 'Safaricom M-Pesa statement',
    ncbaLoop => 'NCBA Loop wallet statement',
    coopYea => 'Co-operative Bank YEA statement',
  };
}

abstract interface class StatementAdapter {
  StatementProvider get provider;
  ParsedStatement parseCsv(Uint8List bytes);
  ParsedStatement parsePdfText(String text);
}
