import 'package:bizlens/core/mpesa/models.dart';
import 'package:bizlens/core/mpesa/pdf_table_layout.dart';
import 'package:bizlens/core/mpesa/statement_parser.dart';
import 'package:flutter_test/flutter_test.dart';

StatementWord word(String text, double x, double y) =>
    StatementWord(text, x, x + text.length * 4, y, y + 8);
List<StatementWord> page({
  bool balance = true,
  String receipt = 'QA26A00001',
  bool failed = false,
}) => [
  word('Summary', 30, 5),
  word('100,000.00', 420, 5),
  word('Receipt', 30, 40),
  word('Completion', 100, 40),
  word('Details', 190, 40),
  word('Transaction', 330, 40),
  word('Paid', 415, 40),
  word('Withdrawn', 472, 40),
  word('Balance', 535, 40),
  word(receipt, 30, 70),
  word('01/01/2026', 100, 70),
  word('08:00:00', 100, 80),
  word('Customer Payment', 190, 70),
  word('from Amina 100.00', 190, 80),
  word(failed ? 'Failed' : 'Completed', 330, 70),
  word('10.00', 438, 70),
  if (balance) word('100.00', 550, 70),
  word('Page 1 of 2', 30, 200),
];

void main() {
  test(
    'dates mentioned in Details cannot widen the completion-time column',
    () {
      final words = page()
          .where((w) => w.top < 60)
          .map(
            (w) => w.text == 'Details'
                ? StatementWord(w.text, 245, 273, w.top, w.bottom)
                : w,
          )
          .toList();
      for (var i = 0; i < 2; i++) {
        final y = 70.0 + i * 32;
        words.addAll([
          word('QA26C0000${i + 1}', 30, y),
          word('01/01/2026', 100, y),
          word('08:00:00', 145, y),
          word('Completed', 330, y),
          word('1.00', 438, y),
          word('100.00', 550, y),
        ]);
        words.addAll(
          i == 0
              ? [word('Invoice', 190, y), word('01/12/2025', 190, y + 10)]
              : [word('Charge', 190, y)],
        );
      }
      final table = PdfStatementTable()..addPage(words);
      final rows = const MpesaStatementParser()
          .parsePdfText(table.encode())
          .transactions;
      expect(rows[0].details, 'Invoice 01/12/2025');
      expect(rows[1].details, 'Charge');
      expect(rows.every((r) => r.at == DateTime.utc(2026, 1, 1, 5)), isTrue);
    },
  );
  test(
    'centred Details heading cannot put descriptions into the date cell',
    () {
      final words = page()
          .map(
            (w) => w.text == 'Details'
                ? StatementWord(w.text, 245, 273, w.top, w.bottom)
                : w,
          )
          .toList();
      final table = PdfStatementTable()..addPage(words);
      final row = const MpesaStatementParser()
          .parsePdfText(table.encode())
          .transactions
          .single;
      expect(row.at, DateTime.utc(2026, 1, 1, 5));
      expect(row.details, 'Customer Payment from Amina 100.00');
    },
  );
  test(
    'compact rows with descriptions above receipt glyph tops stay separate',
    () {
      final words = page().where((w) => w.top < 60).toList();
      for (var i = 0; i < 3; i++) {
        final y = 70.0 + i * 14;
        words.addAll([
          word('QA26B0000${i + 1}', 30, y),
          word('01/01/2026 08:00:00', 100, y),
          word('Fabricated fee ${i + 1}', 190, y - 6),
          word('Completed', 330, y),
          word('1.00', 438, y),
          word('100.00', 550, y),
        ]);
      }
      final table = PdfStatementTable()..addPage(words);
      final rows = const MpesaStatementParser()
          .parsePdfText(table.encode())
          .transactions;
      expect(rows.length, 3);
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i].details, 'Fabricated fee ${i + 1}');
      }
    },
  );
  List<StatementWord> footer() => [
    word('This', 30, 96),
    word('is', 50, 96),
    word('a', 62, 96),
    word('computer', 70, 96),
    word('generated', 106, 96),
    word('statement', 146, 96),
  ];
  test(
    'close computer-generated footer cannot enter the last receipt cell',
    () {
      final table = PdfStatementTable()..addPage([...page(), ...footer()]);
      final result = const MpesaStatementParser().parsePdfText(table.encode());
      expect(result.transactions.length, 1);
      expect(result.transactions.single.receipt, 'QA26A00001');
      expect(
        result.transactions.single.details,
        'Customer Payment from Amina 100.00',
      );
      expect(result.transactions.single.balance, 10000);
    },
  );
  test('footer boundary cannot silently discard another transaction', () {
    final second = page(receipt: 'QA26A00002')
        .where((w) => w.top >= 70 && w.top < 100)
        .map(
          (w) =>
              StatementWord(w.text, w.left, w.right, w.top + 50, w.bottom + 50),
        );
    expect(
      () => PdfStatementTable().addPage([...page(), ...footer(), ...second]),
      throwsA(isA<StatementImportException>()),
    );
  });
  test(
    'a merchant description is not a footer merely because it says Safaricom',
    () {
      final table = PdfStatementTable()
        ..addPage([...page(), word('Safaricom merchant', 190, 90)]);
      expect(
        const MpesaStatementParser()
            .parsePdfText(table.encode())
            .transactions
            .single
            .details,
        contains('Safaricom merchant'),
      );
    },
  );
  test('row diagnostics report only page, row and fixed column names', () {
    final table = PdfStatementTable()..addPage(page());
    try {
      table.addPage(page(balance: false));
      fail('Missing balance must reject the import');
    } on StatementImportException catch (error) {
      expect(error.message, contains('[ROW_CELLS]'));
      expect(error.message, contains('page 2, row 1'));
      expect(error.message, contains('table row 2'));
      expect(error.message, contains('Missing columns: Balance'));
      for (final value in [
        'QA26A00001',
        '01/01/2026',
        '08:00:00',
        'Amina',
        '100.00',
        '10.00',
        'Completed',
      ]) {
        expect(error.message, isNot(contains(value)));
      }
    }
  });
  test('receipt conflicts identify the column without exposing its text', () {
    try {
      PdfStatementTable().addPage([...page(), word('PRIVATE_CANARY', 30, 80)]);
      fail('Overlapping receipt content must reject the import');
    } on StatementImportException catch (error) {
      expect(error.message, contains('Conflicting columns: Receipt No.'));
      expect(error.message, isNot(contains('PRIVATE_CANARY')));
    }
  });
  test(
    'blank outgoing keeps incoming direction and ignores summary/footer',
    () {
      final table = PdfStatementTable()..addPage(page());
      final tx = const MpesaStatementParser()
          .parsePdfText(table.encode())
          .transactions
          .single;
      expect(tx.paidIn, 1000);
      expect(tx.withdrawn, 0);
      expect(tx.balance, 10000);
      expect(tx.details, 'Customer Payment from Amina 100.00');
      expect(tx.at, DateTime.utc(2026, 1, 1, 5));
    },
  );
  test('column ordering comes from geometry rather than PDF content order', () {
    final table = PdfStatementTable()
      ..addPage(page().reversed.toList())
      ..addPage(page(receipt: 'QA26A00002'));
    expect(
      const MpesaStatementParser()
          .parsePdfText(table.encode())
          .transactions
          .length,
      2,
    );
  });
  test('a missing balance cannot create an invented zero balance', () {
    expect(
      () => PdfStatementTable().addPage(page(balance: false)),
      throwsA(isA<StatementImportException>()),
    );
  });
  test('malformed receipt cannot hide among readable rows', () {
    expect(
      () => PdfStatementTable().addPage(page(receipt: 'BAD')),
      throwsA(isA<StatementImportException>()),
    );
  });
  test('failed status uses the same explicit exclusion rule as CSV', () {
    final table = PdfStatementTable()
      ..addPage(page())
      ..addPage(page(receipt: 'QA26A00002', failed: true));
    final result = const MpesaStatementParser().parsePdfText(table.encode());
    expect(result.transactions.length, 1);
    expect(result.warnings.join(), contains('1 unsuccessful'));
  });
}
