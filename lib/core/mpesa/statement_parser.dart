import 'dart:convert';
import 'dart:typed_data';

import 'models.dart';
import 'pdf_table_layout.dart';

/// Decimal parsing without binary floating point. Withdrawal columns may use
/// signed negatives; direction remains defined by the column, not the sign.
int parseMoney(String input, {required int row, bool absolute = false}) {
  var s = input
      .trim()
      .replaceAll(RegExp(r'KES|KSHS?\.?', caseSensitive: false), '')
      .replaceAll(RegExp(r'[,\s\u00a0]'), '');
  if (s.isEmpty || s == '-' || s == '--') return 0;
  if (s.startsWith('(') && s.endsWith(')')) {
    s = '-${s.substring(1, s.length - 1)}';
  }
  if (!RegExp(r'^-?\d+(?:\.\d{1,2})?$').hasMatch(s)) {
    throw StatementImportException(
      'Row $row has an invalid KES amount. Use at most two decimal places.',
    );
  }
  final negative = s.startsWith('-');
  final parts = (negative ? s.substring(1) : s).split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 1000000000000) {
    throw StatementImportException(
      'Row $row has an amount outside the supported range.',
    );
  }
  final cents =
      whole * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  return negative && !absolute ? -cents : cents;
}

DateTime parseStatementDate(String value, {required int row}) {
  final s = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2}|\d{2}/\d{2}/\d{4})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?(Z|[+-]\d{2}:?\d{2})?$',
  ).firstMatch(s);
  if (match == null) {
    throw StatementImportException(
      'Row $row has an unsupported date/time. Use dd/MM/yyyy HH:mm:ss or yyyy-MM-dd HH:mm:ss.',
    );
  }
  final d = match.group(1)!;
  final parts = d.split(d.contains('/') ? '/' : '-').map(int.parse).toList();
  final year = d.contains('/') ? parts[2] : parts[0];
  final month = parts[1];
  final day = d.contains('/') ? parts[0] : parts[2];
  final hour = int.parse(match.group(2)!);
  final minute = int.parse(match.group(3)!);
  final second = int.parse(match.group(4) ?? '0');
  final local = DateTime.utc(year, month, day, hour, minute, second);
  if (year < 2000 ||
      year > 2200 ||
      local.year != year ||
      local.month != month ||
      local.day != day ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    throw StatementImportException(
      'Row $row has an invalid calendar date/time.',
    );
  }
  final zone = match.group(5);
  if (zone != null) {
    if (zone != 'Z') {
      final digits = zone.substring(1).replaceAll(':', '');
      final hours = int.parse(digits.substring(0, 2));
      final minutes = int.parse(digits.substring(2));
      if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0)) {
        throw StatementImportException('Row $row has an invalid time zone.');
      }
    }
    final iso = '${local.toIso8601String().replaceFirst('Z', '')}$zone';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      throw StatementImportException('Row $row has an invalid time zone.');
    }
    return parsed.toUtc();
  }
  return local.subtract(const Duration(hours: 3));
}

class MpesaStatementParser {
  const MpesaStatementParser();
  static const maxRows = 50000;
  static String _header(String v) =>
      v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  static const _receipt = [
    'receiptno',
    'receiptnumber',
    'receipt',
    'transactionid',
  ];
  static const _date = [
    'completiontime',
    'datetime',
    'transactiondate',
    'date',
  ];
  static const _in = ['paidin', 'moneyin', 'credit'];
  static const _out = ['withdrawn', 'moneyout', 'debit'];

  ParsedStatement parseCsv(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const StatementImportException('The selected file is empty.');
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      // UTF-16 exports are common; support explicit BOMs, not guessed encodings.
      if (bytes.length > 2 && bytes[0] == 255 && bytes[1] == 254) {
        text = String.fromCharCodes(
          List.generate(
            (bytes.length - 2) ~/ 2,
            (i) => bytes[2 + i * 2] | bytes[3 + i * 2] << 8,
          ),
        );
      } else {
        throw const StatementImportException(
          'CSV encoding is unsupported. Export it as UTF-8 CSV and try again.',
        );
      }
    }
    if (text.trim().isEmpty) {
      throw const StatementImportException('The selected file is empty.');
    }
    text = text.replaceAll('\ufeff', '');
    final candidate = text
        .split(RegExp(r'\r?\n'))
        .firstWhere(
          (v) => _receipt.any((h) => _header(v).contains(h)),
          orElse: () => '',
        );
    final delimiter =
        ';'.allMatches(candidate).length > ','.allMatches(candidate).length
        ? ';'
        : ',';
    final rows = _csv(text, delimiter);
    var headerIndex = -1;
    List<String> headers = [];
    for (var i = 0; i < rows.length; i++) {
      final h = rows[i].map(_header).toList();
      if (h.any(_receipt.contains) &&
          h.any(_date.contains) &&
          h.contains('details')) {
        headerIndex = i;
        headers = h;
        break;
      }
    }
    if (headerIndex < 0) {
      throw const StatementImportException(
        'This is not a supported M-Pesa CSV. Required columns: Receipt No., Completion Time, Details, Paid In, Withdrawn, Balance.',
      );
    }
    int col(List<String> aliases) => headers.indexWhere(aliases.contains);
    final ri = col(_receipt), di = col(_date), ti = col(['time']);
    final ni = col(_in), oi = col(_out), bi = col(['balance']);
    final detailIndex = col(['details']),
        si = col(['transactionstatus', 'status']);
    if ([ri, di, ni, oi, bi, detailIndex].any((v) => v < 0)) {
      throw const StatementImportException(
        'CSV is missing a required transaction column: receipt, date/time, details, paid in, withdrawn or balance.',
      );
    }
    final transactions = <MpesaTransaction>[];
    var skipped = 0;
    for (var i = headerIndex + 1; i < rows.length; i++) {
      final cells = rows[i];
      if (cells.every((v) => v.trim().isEmpty)) continue;
      String cell(int index) =>
          index < 0 || index >= cells.length ? '' : cells[index].trim();
      if (_receipt.contains(_header(cell(ri)))) {
        continue; // Repeated page header.
      }
      if (RegExp(
        r'^(total|summary|end of statement)',
        caseSensitive: false,
      ).hasMatch(cell(ri))) {
        continue;
      }
      if (si >= 0 &&
          ![
            '',
            'completed',
            'successful',
            'success',
          ].contains(cell(si).toLowerCase())) {
        skipped++;
        continue;
      }
      final date = ti >= 0 ? '${cell(di)} ${cell(ti)}' : cell(di);
      transactions.add(
        _row(
          i + 1,
          cell(ri),
          date,
          cell(detailIndex),
          cell(ni),
          cell(oi),
          cell(bi),
        ),
      );
      if (transactions.length > maxRows) {
        throw const StatementImportException(
          'Statement exceeds 50,000 rows. Import a shorter date range.',
        );
      }
    }
    return _finish(transactions, skipped);
  }

  ParsedStatement parsePdfText(String text) {
    if (text.startsWith(PdfStatementTable.marker)) {
      return parseCsv(
        Uint8List.fromList(
          utf8.encode(text.substring(PdfStatementTable.marker.length)),
        ),
      );
    }
    if (text.trim().isEmpty) {
      throw const StatementImportException(
        'This PDF has no selectable text. Scanned/image statements are not supported; use a text PDF or CSV.',
      );
    }
    if (!RegExp(
          r'receipt\s*(?:no\.?|number)',
          caseSensitive: false,
        ).hasMatch(text) ||
        !RegExp(r'paid\s*in', caseSensitive: false).hasMatch(text)) {
      throw const StatementImportException(
        'This PDF does not contain a supported M-Pesa transaction table. Try the CSV export.',
      );
    }
    final cleaned = text
        .replaceAll('\u2212', '-')
        .replaceAll('|', ' ')
        .split(RegExp(r'\r?\n'))
        .where(
          (line) => !RegExp(
            r'^\s*(?:Receipt\s|Page\s+\d|FABRICATED|M-PESA STATEMENT|Statement period|This is a fabricated|Total\s|Safaricom)',
            caseSensitive: false,
          ).hasMatch(line),
        )
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final start = RegExp(
      r'\b([A-Z0-9]{8,15})\s+(\d{4}-\d{2}-\d{2}|\d{2}/\d{2}/\d{4})\s+(\d{1,2}:\d{2}(?::\d{2})?)\b',
    );
    final matches = start.allMatches(cleaned).toList();
    final candidates = RegExp(r'\b[A-Z0-9]{8,15}\s+\d{2,4}[-/]')
        .allMatches(cleaned)
        .length;
    if (candidates != matches.length) {
      throw const StatementImportException(
        'Some PDF transaction dates could not be read reliably. No partial import was saved. Try the CSV export.',
      );
    }
    if (matches.length > maxRows) {
      throw const StatementImportException(
        'Statement exceeds 50,000 rows. Import a shorter date range.',
      );
    }
    final transactions = <MpesaTransaction>[];
    var skipped = 0;
    const amount = r'(?:\(?-?\d[\d,]*\.\d{2}\)?|--|-)';
    final tail = RegExp(
      '^(.*?)\\s+($amount)\\s+($amount)\\s+($amount)(?:\\s|\$)',
    );
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final end = i + 1 < matches.length
          ? matches[i + 1].start
          : cleaned.length;
      final rest = cleaned.substring(m.end, end).trim();
      final amounts = tail.firstMatch(rest);
      if (amounts == null) {
        throw StatementImportException(
          'PDF transaction ${i + 1} could not be read reliably. Try the CSV export.',
        );
      }
      if (rest.substring(amounts.end).trim().isNotEmpty) {
        throw StatementImportException(
          'PDF transaction ${i + 1} has unsupported trailing text. No partial import was saved. Try the CSV export.',
        );
      }
      var details = amounts.group(1)!.trim();
      if (RegExp(
        r'\b(?:failed|cancelled|canceled)\s*$',
        caseSensitive: false,
      ).hasMatch(details)) {
        skipped++;
        continue;
      }
      details = details.replaceFirst(
        RegExp(r'\s+(?:completed|successful)\s*$', caseSensitive: false),
        '',
      );
      transactions.add(
        _row(
          i + 1,
          m.group(1)!,
          '${m.group(2)} ${m.group(3)}',
          details,
          amounts.group(2)!,
          amounts.group(3)!,
          amounts.group(4)!,
        ),
      );
    }
    return _finish(transactions, skipped);
  }

  ParsedStatement _finish(List<MpesaTransaction> rows, int skipped) {
    if (rows.isEmpty) {
      throw const StatementImportException(
        'No completed M-Pesa transactions were found in this statement.',
      );
    }
    return ParsedStatement(rows, [
      'Times without a zone are interpreted as Kenya time (UTC+3).',
      if (skipped > 0) '$skipped unsuccessful transaction(s) were excluded.',
    ]);
  }

  MpesaTransaction _row(
    int row,
    String receipt,
    String date,
    String details,
    String incoming,
    String outgoing,
    String balance,
  ) {
    if (!RegExp(r'^[a-zA-Z0-9-]{6,20}$').hasMatch(receipt)) {
      throw StatementImportException('Row $row has an invalid receipt number.');
    }
    if (details.isEmpty) {
      throw StatementImportException(
        'Row $row is missing transaction details.',
      );
    }
    final paidIn = parseMoney(incoming, row: row);
    final withdrawn = parseMoney(outgoing, row: row, absolute: true);
    if (paidIn < 0 || (paidIn > 0 && withdrawn > 0)) {
      throw StatementImportException(
        'Row $row has ambiguous money-in/money-out amounts. Please check the original statement.',
      );
    }
    return MpesaTransaction(
      row: row,
      at: parseStatementDate(date, row: row),
      receipt: receipt.toUpperCase(),
      details: details,
      paidIn: paidIn,
      withdrawn: withdrawn,
      balance: ['', '-', '--'].contains(balance.trim())
          ? null
          : parseMoney(balance, row: row),
    );
  }

  List<List<String>> _csv(String text, String delimiter) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else if (quoted) {
          quoted = false;
          closed = true;
        } else if (field.toString().trim().isEmpty && !closed) {
          quoted = true;
          field = StringBuffer();
        } else {
          throw const StatementImportException(
            'CSV contains malformed quotation marks. Export a fresh CSV.',
          );
        }
      } else if (!quoted && (c == delimiter || c == '\n' || c == '\r')) {
        row.add(field.toString());
        field = StringBuffer();
        closed = false;
        if (c != delimiter) {
          rows.add(row);
          row = [];
          if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        }
      } else {
        if (closed && c.trim().isNotEmpty) {
          throw const StatementImportException(
            'CSV contains text after a quoted field. Export a fresh CSV.',
          );
        }
        if (!closed) field.write(c);
      }
    }
    if (quoted) {
      throw const StatementImportException(
        'CSV has an unclosed quoted field. Export a fresh CSV.',
      );
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
