import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/core/finance/obligation.dart';

void main() {
  test('summarizes debtor, creditor, settled and overdue balances', () {
    final rows = [
      ObligationRecord(
        id: 'd1',
        kind: ObligationKind.debtor,
        party: 'Customer',
        description: 'Goods',
        originalMinor: 10000,
        settledMinor: 2500,
        createdAt: DateTime.utc(2026, 1, 1),
        dueAt: DateTime.utc(2026, 1, 5),
      ),
      ObligationRecord(
        id: 'c1',
        kind: ObligationKind.creditor,
        party: 'Supplier',
        description: 'Stock',
        originalMinor: 6000,
        settledMinor: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        dueAt: DateTime.utc(2026, 1, 20),
      ),
      ObligationRecord(
        id: 'd2',
        kind: ObligationKind.debtor,
        party: 'Customer 2',
        description: 'Paid goods',
        originalMinor: 2000,
        settledMinor: 2000,
        createdAt: DateTime.utc(2026, 1, 1),
        dueAt: DateTime.utc(2026, 1, 2),
      ),
    ];
    final result = const ObligationAnalyser().analyse(
      rows,
      asOf: DateTime.utc(2026, 1, 10),
    );
    expect(result.debtorOutstandingMinor, 7500);
    expect(result.creditorOutstandingMinor, 6000);
    expect(result.openCount, 2);
    expect(result.overdueCount, 1);
  });

  test('rejects overpayment and duplicate IDs', () {
    final row = ObligationRecord(
      id: 'd1',
      kind: ObligationKind.debtor,
      party: 'Customer',
      description: 'Goods',
      originalMinor: 100,
      settledMinor: 101,
      createdAt: DateTime.utc(2026),
    );
    expect(
      () => const ObligationAnalyser().analyse([row]),
      throwsFormatException,
    );
  });
}
