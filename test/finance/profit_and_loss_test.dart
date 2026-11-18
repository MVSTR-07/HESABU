import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/core/expenses/expense_analysis.dart';
import 'package:hesabu/core/finance/profit_and_loss.dart';
import 'package:hesabu/core/sales/sales_analysis.dart';

void main() {
  test('calculates recorded sales less expenses within Kenya date range', () {
    final result = const ProfitAndLossAnalyser().analyse(
      from: DateTime.utc(2026, 10, 1),
      through: DateTime.utc(2026, 10, 31),
      sales: [
        SaleRecord(
          id: 's1',
          soldAt: DateTime.utc(2026, 10, 2, 8),
          product: 'Tea',
          quantity: 2,
          unitPriceMinor: 50000,
        ),
        SaleRecord(
          id: 'outside',
          soldAt: DateTime.utc(2026, 11, 1),
          product: 'Tea',
          quantity: 1,
          unitPriceMinor: 20000,
        ),
      ],
      expenses: [
        ExpenseRecord(
          id: 'e1',
          spentAt: DateTime.utc(2026, 10, 4),
          category: 'Rent',
          description: 'Rent',
          amountMinor: 30000,
        ),
      ],
    );
    expect(result.salesMinor, 100000);
    expect(result.expensesMinor, 30000);
    expect(result.operatingSurplusMinor, 70000);
    expect(result.salesCount, 1);
    expect(result.surplusMargin, .7);
  });

  test('rejects reversed report period', () {
    expect(
      () => const ProfitAndLossAnalyser().analyse(
        from: DateTime.utc(2026, 10, 2),
        through: DateTime.utc(2026, 10, 1),
        sales: const [],
        expenses: const [],
      ),
      throwsFormatException,
    );
  });
}
