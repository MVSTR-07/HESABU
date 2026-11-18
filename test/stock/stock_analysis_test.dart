import 'package:hesabu/core/sample_data.dart';
import 'package:hesabu/core/stock/stock_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('on-hand quantities, value, reorder and movement rank are correct', () {
    final result = const StockAnalyser().analyse([
      StockItem(
        id: '1',
        name: 'Flour',
        unit: 'bags',
        openingQuantity: 20,
        receivedQuantity: 10,
        soldQuantity: 24,
        damagedQuantity: 1,
        unitCostMinor: 10000,
        reorderLevel: 8,
        updatedAt: DateTime.utc(2026),
      ),
      StockItem(
        id: '2',
        name: 'Rice',
        unit: 'bags',
        openingQuantity: 5,
        receivedQuantity: 0,
        soldQuantity: 5,
        damagedQuantity: 0,
        unitCostMinor: 20000,
        reorderLevel: 2,
        updatedAt: DateTime.utc(2026),
      ),
    ]);
    expect(result.itemCount, 2);
    expect(result.unitsOnHand, 5);
    expect(result.valueMinor, 50000);
    expect(result.lowStock.map((v) => v.id), ['2', '1']);
    expect(result.outOfStock.single.name, 'Rice');
    expect(result.fastMovers.first.name, 'Flour');
  });

  test('stock cannot have negative quantities or oversell available units', () {
    const analyser = StockAnalyser();
    expect(
      () => analyser.analyse([
        StockItem(
          id: 'negative',
          name: 'Beans',
          unit: 'kg',
          openingQuantity: -1,
          receivedQuantity: 0,
          soldQuantity: 0,
          damagedQuantity: 0,
          unitCostMinor: 10,
          reorderLevel: 0,
          updatedAt: DateTime.utc(2026),
        ),
      ]),
      throwsFormatException,
    );
    expect(
      () => analyser.analyse([
        StockItem(
          id: 'oversold',
          name: 'Beans',
          unit: 'kg',
          openingQuantity: 2,
          receivedQuantity: 0,
          soldQuantity: 3,
          damagedQuantity: 0,
          unitCostMinor: 10,
          reorderLevel: 0,
          updatedAt: DateTime.utc(2026),
        ),
      ]),
      throwsFormatException,
    );
  });

  test('fabricated inventory covers fast, low and out-of-stock items', () {
    final result = const StockAnalyser().analyse(generateSampleStock());
    expect(result.itemCount, 8);
    expect(result.lowStock, isNotEmpty);
    expect(result.outOfStock, isNotEmpty);
    expect(result.fastMovers, isNotEmpty);
    expect(result.valueMinor, greaterThan(0));
  });
}
