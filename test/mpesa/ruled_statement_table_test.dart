import 'package:bizlens/core/mpesa/models.dart';
import 'package:bizlens/core/mpesa/pdf_table_layout.dart';
import 'package:bizlens/core/mpesa/ruled_statement_table.dart';
import 'package:bizlens/core/mpesa/statement_parser.dart';
import 'package:flutter_test/flutter_test.dart';

StatementWord w(String value, double x, double y) =>
    StatementWord(value, x, x + value.length * 4, y, y + 8);
const xs = [0.0, 80.0, 180.0, 340.0, 430.0, 500.0, 570.0, 650.0];
List<StatementRule> rules() => [
  for (final x in xs) StatementRule(x, 40, x, 140),
  for (final y in [40.0, 54.0, 80.0, 120.0, 140.0]) StatementRule(0, y, 650, y),
  for (final x in [0.0, 210.0, 430.0, 650.0]) StatementRule(x, 0, x, 30),
  for (final y in [0.0, 15.0, 30.0]) StatementRule(0, y, 650, y),
  for (final x in [0.0, 320.0, 650.0]) StatementRule(x, 160, x, 190),
  for (final y in [160.0, 175.0, 190.0]) StatementRule(0, y, 650, y),
];
List<StatementWord> words() => [
  w('SUMMARY', 10, 5),
  w('Paid', 220, 5),
  w('Out', 440, 5),
  w('Receipt', 10, 44),
  w('Completion', 90, 44),
  w('Details', 245, 44),
  w('Transaction', 345, 44),
  w('Paid', 445, 44),
  w('Withdrawn', 505, 44),
  w('Balance', 580, 44),
  w('FAKE00001', 10, 59),
  w('01/01/2026 10:00:00', 84, 57),
  w('Charge', 185, 56),
  w('Completed', 345, 58),
  w('5.00', 530, 60),
  w('95.00', 610, 60),
  w('FAKE00002', 10, 94),
  w('02/01/2026 11:00:00', 84, 94),
  w('Invoice', 185, 85),
  w('01/12/2025', 185, 97),
  w('continuation', 185, 108),
  w('Completed', 345, 94),
  w('10.00', 445, 94),
  w('105.00', 610, 94),
  w('FAKE00003', 10, 126),
  w('03/01/2026 11:00:00', 84, 126),
  w('Completed', 345, 126),
  w('1.00', 445, 126),
  w('106.00', 610, 126),
  w('Footer', 10, 164),
  w('not a transaction', 330, 164),
];

void main() {
  test(
    'seven physical columns ignore summary/footer and preserve wrapped cells',
    () {
      final rows = RuledStatementTable().extract(words(), rules(), page: 2)!;
      expect(rows.length, 3);
      expect(rows[0][2], 'Charge');
      expect(rows[0][4], '');
      expect(rows[0][5], '5.00');
      expect(rows[1][2], 'Invoice 01/12/2025 continuation');
      expect(rows[1][5], '');
      final table = PdfStatementTable()..addPage(words(), rules: rules());
      final parsed = const MpesaStatementParser()
          .parsePdfText(table.encode())
          .transactions;
      expect(parsed.length, 3);
      expect(parsed.first.withdrawn, 500);
      expect(parsed[1].paidIn, 1000);
      expect(parsed[2].details, RuledStatementTable.unavailableDescription);
    },
  );
  test(
    'missing descriptive text is retained visibly, not invented or dropped',
    () {
      final rows = RuledStatementTable().extract(words(), rules(), page: 1)!;
      expect(rows[2][2], RuledStatementTable.unavailableDescription);
      expect(rows[2][6], '106.00');
    },
  );
  test(
    'missing balance rejects a financial row rather than inventing zero',
    () {
      expect(
        () => RuledStatementTable().extract(
          words().where((v) => v.text != '105.00').toList(),
          rules(),
          page: 1,
        ),
        throwsA(isA<StatementImportException>()),
      );
    },
  );
  test('broken horizontal border cannot merge two payments silently', () {
    expect(
      () => RuledStatementTable().extract(
        words(),
        rules().where((r) => !(r.horizontal && r.top == 120)).toList(),
        page: 1,
      ),
      throwsA(isA<StatementImportException>()),
    );
  });
  test(
    'a document without a closed grid uses the existing text-table reader',
    () {
      expect(RuledStatementTable().extract(words(), const [], page: 1), isNull);
    },
  );
}
