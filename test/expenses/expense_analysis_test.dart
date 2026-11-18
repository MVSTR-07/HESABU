import 'package:hesabu/core/expenses/expense_analysis.dart';
import 'package:hesabu/core/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expenses total by category, month and largest record', () {
    final rows = [
      ExpenseRecord(
        id: '1',
        spentAt: DateTime.utc(2026, 10, 1, 21),
        category: 'Transport',
        description: 'Delivery fare',
        amountMinor: 120000,
      ),
      ExpenseRecord(
        id: '2',
        spentAt: DateTime.utc(2026, 10, 2, 7),
        category: 'Stock',
        description: 'Flour',
        amountMinor: 900000,
      ),
      ExpenseRecord(
        id: '3',
        spentAt: DateTime.utc(2026, 9, 2),
        category: 'Transport',
        description: 'Pickup',
        amountMinor: 80000,
      ),
    ];
    final result = const ExpenseAnalyser().analyse(rows);
    expect(result.totalMinor, 1100000);
    expect(result.count, 3);
    expect(result.averageMinor, 366667);
    expect(result.categories.first.category, 'Stock');
    expect(result.categories.last.count, 2);
    expect(result.months.length, 2);
    expect(result.largest?.description, 'Flour');
  });

  test('category, description, amount and IDs are validated', () {
    const analyser = ExpenseAnalyser();
    final record = ExpenseRecord(
      id: 'same',
      spentAt: DateTime.utc(2026),
      category: 'Rent',
      description: 'Shop rent',
      amountMinor: 100,
    );
    expect(() => analyser.analyse([record, record]), throwsFormatException);
    expect(
      () => analyser.analyse([
        ExpenseRecord(
          id: 'zero',
          spentAt: DateTime.utc(2026),
          category: 'Rent',
          description: 'Shop rent',
          amountMinor: 0,
        ),
      ]),
      throwsFormatException,
    );
  });

  test('fabricated expenses include multiple Kenyan small-business costs', () {
    final result = const ExpenseAnalyser().analyse(generateSampleExpenses());
    expect(result.count, 10);
    expect(result.categories.length, greaterThan(3));
    expect(result.largest, isNotNull);
  });
}
