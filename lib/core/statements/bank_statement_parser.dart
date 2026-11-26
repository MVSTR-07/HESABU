import 'dart:convert';
import 'dart:typed_data';

import '../mpesa/models.dart';
import '../mpesa/statement_parser.dart' show parseMoney, parseStatementDate;

/// Parser shared by the bank adapters.  Each adapter supplies its own column
/// aliases and PDF row shape; no provider is guessed from transaction text.
class BankStatementParser {
  const BankStatementParser({required this.providerName});
  final String providerName;

  ParsedStatement parseCsv(Uint8List bytes) {
    if (bytes.isEmpty)
      throw const StatementImportException('The selected file is empty.');
    final text = utf8
        .decode(bytes, allowMalformed: false)
        .replaceAll('\ufeff', '');
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((v) => v.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty)
      throw const StatementImportException('The selected file is empty.');
    final delimiter =
        lines.first.split(';').length > lines.first.split(',').length
        ? ';'
        : ',';
    final header = lines.first.split(delimiter).map(_key).toList();
    int find(List<String> names) => header.indexWhere(names.contains);
    final date = find(['date', 'transactiondate', 'valuedate']);
    final details = find([
      'particulars',
      'details',
      'transactiondetails',
      'transactiontypeanddetails',
    ]);
    final moneyOut = find(['moneyout', 'withdrawn', 'debit', 'debits']);
    final moneyIn = find(['moneyin', 'paidin', 'credit', 'credits']);
    final balance = find(['balance', 'closingbalance']);
    final reference = find([
      'refnumber',
      'reference',
      'receiptno',
      'transactionid',
    ]);
    if ([date, details, moneyOut, moneyIn, balance].any((v) => v < 0)) {
      throw StatementImportException(
        '$providerName CSV is missing Date, Details, Money In, Money Out or Balance columns.',
      );
    }
    final rows = <MpesaTransaction>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = lines[i].split(delimiter).map((v) => v.trim()).toList();
      String cell(int n) => n >= 0 && n < cells.length ? cells[n] : '';
      if (cell(date).isEmpty ||
          RegExp(
            r'^(total|opening|closing|page)',
            caseSensitive: false,
          ).hasMatch(cell(date)))
        continue;
      rows.add(
        _row(
          i + 1,
          reference >= 0 && cell(reference).isNotEmpty
              ? cell(reference)
              : '$providerName${i.toString().padLeft(6, '0')}',
          cell(date),
          cell(details),
          cell(moneyIn),
          cell(moneyOut),
          cell(balance),
        ),
      );
    }
    return _finish(rows);
  }

  ParsedStatement parsePdfRows(
    Iterable<String> lines, {
    required RegExp rowPattern,
  }) {
    final rows = <MpesaTransaction>[];
    for (final line in lines) {
      final m = rowPattern.firstMatch(line.trim());
      if (m == null) continue;
      rows.add(
        _row(
          rows.length + 1,
          m.namedGroup('ref') ??
              '${providerName}${rows.length.toString().padLeft(6, '0')}',
          m.namedGroup('date')!,
          m.namedGroup('details')!,
          m.namedGroup('in')!,
          m.namedGroup('out')!,
          m.namedGroup('balance')!,
        ),
      );
    }
    return _finish(rows);
  }

  ParsedStatement parsePdfBlocks(String text, {required RegExp blockStart}) {
    final starts = blockStart.allMatches(text).toList();
    final rows = <MpesaTransaction>[];
    final tail = RegExp(
      r'(?<out>-?[\d,]+(?:\.\d{1,2})?|-)\s+(?<in>-?[\d,]+(?:\.\d{1,2})?|-)\s+(?<balance>-?[\d,]+(?:\.\d{1,2})?)\s*$',
      caseSensitive: false,
    );
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = i + 1 < starts.length ? starts[i + 1].start : text.length;
      final block = text
          .substring(start.start, end)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final amounts = tail.firstMatch(block);
      if (amounts == null) continue;
      var details = block.substring(start.end, amounts.start).trim();
      details = details
          .replaceAll(RegExp(r'\b\d{1,2}\s+[A-Za-z]{3}\s+\d{2,4}\b'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      rows.add(
        _row(
          rows.length + 1,
          '${providerName}${rows.length.toString().padLeft(6, '0')}',
          start.group(1)!,
          details,
          amounts.namedGroup('in')!,
          amounts.namedGroup('out')!,
          amounts.namedGroup('balance')!,
        ),
      );
    }
    return _finish(rows);
  }

  MpesaTransaction _row(
    int row,
    String ref,
    String date,
    String details,
    String incoming,
    String outgoing,
    String closing,
  ) {
    final safeRef = ref.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '').toUpperCase();
    var receipt = safeRef.isEmpty ? '${providerName}000001' : safeRef;
    if (receipt.length < 6) receipt = '${receipt}000000'.substring(0, 6);
    if (receipt.length > 20) receipt = receipt.substring(0, 20);
    return MpesaTransaction(
      row: row,
      at: _date(date, row),
      receipt: receipt,
      details: details.trim().isEmpty
          ? 'Unspecified transaction'
          : details.trim(),
      paidIn: parseMoney(incoming, row: row, absolute: true),
      withdrawn: parseMoney(outgoing, row: row, absolute: true),
      balance: closing.trim().isEmpty ? null : parseMoney(closing, row: row),
    );
  }

  DateTime _date(String value, int row) {
    final v = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final withTime = RegExp(r'\d{1,2}:\d{2}').hasMatch(v) ? v : '$v 00:00:00';
    try {
      return parseStatementDate(_normaliseDate(withTime), row: row);
    } catch (_) {
      throw StatementImportException(
        'Row $row has an unsupported $providerName date.',
      );
    }
  }

  String _normaliseDate(String value) {
    final m = RegExp(
      r'^(\d{1,2})[-/\s]+([A-Za-z]{3}|\d{1,2})[-/\s]+(\d{2,4})\s+(.*)$',
    ).firstMatch(value);
    if (m == null) return value;
    const months = {
      'Jan': '01',
      'Feb': '02',
      'Mar': '03',
      'Apr': '04',
      'May': '05',
      'Jun': '06',
      'Jul': '07',
      'Aug': '08',
      'Sep': '09',
      'Oct': '10',
      'Nov': '11',
      'Dec': '12',
    };
    final month = months[m.group(2)] ?? m.group(2)!.padLeft(2, '0');
    var year = m.group(3)!;
    if (year.length == 2) year = '20$year';
    return '$year-$month-${m.group(1)!.padLeft(2, '0')} ${m.group(4)}';
  }

  ParsedStatement _finish(List<MpesaTransaction> rows) {
    if (rows.isEmpty)
      throw StatementImportException(
        'No transaction rows were found in this $providerName statement.',
      );
    return ParsedStatement(rows, [
      'Parsed with the $providerName layout adapter.',
    ]);
  }

  static String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
