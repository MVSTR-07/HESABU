import 'package:hesabu/core/sample_data.dart';
import 'package:hesabu/core/sales/sales_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sales revenue, units, products and Kenya business days are correct',
    () {
      final rows = [
        SaleRecord(
          id: 'A',
          soldAt: DateTime.utc(2026, 10, 1, 21),
          product: 'Flour',
          quantity: 2,
          unitPriceMinor: 18000,
        ),
        SaleRecord(
          id: 'B',
          soldAt: DateTime.utc(2026, 10, 2, 7),
          product: 'Rice',
          quantity: 1,
          unitPriceMinor: 34000,
        ),
        SaleRecord(
          id: 'C',
          soldAt: DateTime.utc(2026, 10, 2, 8),
          product: 'Flour',
          quantity: 1,
          unitPriceMinor: 18000,
        ),
      ];
      final result = const SalesAnalyser().analyse(rows);
      expect(result.revenueMinor, 88000);
      expect(result.saleCount, 3);
      expect(result.unitsSold, 4);
      expect(result.averageSaleMinor, 29333);
      expect(result.products.first.product, 'Flour');
      expect(result.products.first.quantity, 3);
      expect(result.days.first.day, DateTime.utc(2026, 10, 2));
      expect(result.days.first.saleCount, 3);
    },
  );

  test('invalid sale rows and duplicate identities are rejected', () {
    const analyser = SalesAnalyser();
    expect(
      () => analyser.analyse([
        SaleRecord(
          id: 'bad',
          soldAt: DateTime.utc(2026),
          product: '',
          quantity: 1,
          unitPriceMinor: 10,
        ),
      ]),
      throwsFormatException,
    );
    final sale = SaleRecord(
      id: 'same',
      soldAt: DateTime.utc(2026),
      product: 'Tea',
      quantity: 1,
      unitPriceMinor: 10,
    );
    expect(() => analyser.analyse([sale, sale]), throwsFormatException);
  });

  test('fabricated shop sample exercises several products and dates', () {
    final result = const SalesAnalyser().analyse(generateSampleSales());
    expect(result.saleCount, 12);
    expect(result.products.length, greaterThan(4));
    expect(result.revenueMinor, greaterThan(0));
  });
}
