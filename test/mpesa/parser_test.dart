import 'dart:convert';
import 'dart:typed_data';

import 'package:bizlens/core/mpesa/models.dart';
import 'package:bizlens/core/mpesa/statement_parser.dart';
import 'package:bizlens/core/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = MpesaStatementParser();
  test('fabricated CSV keeps all 23 rows, exact cents, UTC and duplicate', () {
    final rows = parser.parseCsv(generateSampleMpesaCsv()).transactions;
    expect(rows.length, 23);
    expect(rows.first.paidIn, 150000);
    expect(rows.first.at, DateTime.utc(2026, 1, 1, 5));
    expect(rows.last.fingerprint, rows[1].fingerprint);
    expect(rows[5].details, contains('Kenya Power, Account'));
  });

  test('BOM, preamble, semicolon, quoted comma/quotes and multiline details', () {
    final text =
        '\ufeffM-PESA statement\r\nReceipt No.;Completion Time;Details;Paid In;Withdrawn;Balance\r\n'
        'QA26A00001;01/02/2026 10:30:00;"Customer Payment from Wanjiku, ""Mama""\nMwangi";"KES 1,234.50";-;"2,000.00"\r\n';
    final tx = parser
        .parseCsv(Uint8List.fromList(utf8.encode(text)))
        .transactions
        .single;
    expect(tx.paidIn, 123450);
    expect(tx.details, contains('"Mama"\nMwangi'));
  });

  test('split date/time and negative withdrawal exports are supported', () {
    final text =
        'Receipt,Date,Time,Details,Credit,Debit,Balance\n'
        'QA26A00001,01/01/2026,09:15:00,Money sent to Kamau,0,-500.00,-100.00\n';
    final tx = parser
        .parseCsv(Uint8List.fromList(utf8.encode(text)))
        .transactions
        .single;
    expect(tx.withdrawn, 50000);
    expect(tx.balance, -10000);
  });

  test('UTF-16 LE exports with BOM are decoded locally', () {
    final text = utf8.decode(generateSampleMpesaCsv());
    final bytes = Uint8List.fromList([
      255,
      254,
      for (final c in text.codeUnits) ...[c & 255, c >> 8],
    ]);
    expect(parser.parseCsv(bytes).transactions.length, 23);
  });

  test('failed transactions are excluded with an explicit warning', () {
    final text = utf8
        .decode(generateSampleMpesaCsv())
        .replaceFirst('Completed', 'Failed');
    final parsed = parser.parseCsv(Uint8List.fromList(utf8.encode(text)));
    expect(parsed.transactions.length, 22);
    expect(parsed.warnings.join(), contains('1 unsuccessful'));
  });

  for (final entry in <String, String>{
    'empty': '',
    'wrong headers': 'name,amount\nWanjiku,20',
    'unclosed quote': '"Receipt No.,Completion Time',
    'bad date': utf8
        .decode(generateSampleMpesaCsv())
        .replaceFirst('01/01/2026', '31/02/2026'),
    'bad money': utf8
        .decode(generateSampleMpesaCsv())
        .replaceFirst('1500.00', '1500.123'),
    'invalid last row':
        '${utf8.decode(generateSampleMpesaCsv())}BAD,not-a-date,private text,Completed,10,0,20\n',
  }.entries) {
    test(
      '${entry.key} returns a safe import error, never a partial import',
      () {
        expect(
          () => parser.parseCsv(Uint8List.fromList(utf8.encode(entry.value))),
          throwsA(isA<StatementImportException>()),
        );
      },
    );
  }

  test('extracted PDF rows handle wrapped lines and repeated page headers', () {
    final text = fabricatedPdfText()
        .replaceFirst('Customer Payment from', 'Customer Payment\nfrom')
        .replaceFirst(
          'QA26A00011',
          'Page 1 of 2\nReceipt No. Completion Time Details Paid In Withdrawn Balance\nQA26A00011',
        );
    expect(parser.parsePdfText(text).transactions.length, 23);
  });

  test('image-only and unrelated PDFs return actionable errors', () {
    expect(
      () => parser.parsePdfText(''),
      throwsA(isA<StatementImportException>()),
    );
    expect(
      () => parser.parsePdfText('An unrelated invoice'),
      throwsA(isA<StatementImportException>()),
    );
  });

  test('a malformed PDF row cannot hide after a readable row', () {
    final badDate = fabricatedPdfText().replaceFirst(
      '02/01/2026',
      '02-01-2026',
    );
    expect(
      () => parser.parsePdfText(badDate),
      throwsA(isA<StatementImportException>()),
    );
    expect(
      () => parser.parsePdfText(
        '${fabricatedPdfText()}\nBAD unsupported transaction 30.00',
      ),
      throwsA(isA<StatementImportException>()),
    );
  });

  test('strict dates and money do not normalise invalid input silently', () {
    expect(
      parseStatementDate('2026-01-01T08:00:00+03:00', row: 1),
      DateTime.utc(2026, 1, 1, 5),
    );
    expect(
      parseStatementDate('2026-01-01T05:00:00Z', row: 1),
      DateTime.utc(2026, 1, 1, 5),
    );
    expect(
      () => parseStatementDate('2026-01-01T05:00:00+99:99', row: 1),
      throwsA(isA<StatementImportException>()),
    );
    expect(
      () => parseStatementDate('01/13/2026 08:00:00', row: 1),
      throwsA(isA<StatementImportException>()),
    );
    expect(parseMoney('(1,234.50)', row: 1, absolute: true), 123450);
    expect(parseMoney('KES 0.01', row: 1), 1);
  });
}

/// Synthetic extraction text, not a checked-in statement file.
String fabricatedPdfText() =>
    'Receipt No. Completion Time Details Status Paid In Withdrawn Balance\n${generateSampleMpesaTransactions().map((v) => '${v.receipt} ${fixtureDate(v.at)} ${v.details} Completed '
        '${(v.paidIn / 100).toStringAsFixed(2)} ${(v.withdrawn / 100).toStringAsFixed(2)} ${(v.balance! / 100).toStringAsFixed(2)}').join('\n')}';
