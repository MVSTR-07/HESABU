/// A local stock snapshot including cumulative activity since opening.
class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.openingQuantity,
    required this.receivedQuantity,
    required this.soldQuantity,
    required this.damagedQuantity,
    required this.unitCostMinor,
    required this.reorderLevel,
    required this.updatedAt,
    this.sku = '',
  });

  final String id;
  final String name;
  final String sku;
  final String unit;
  final int openingQuantity;
  final int receivedQuantity;
  final int soldQuantity;
  final int damagedQuantity;
  final int unitCostMinor;
  final int reorderLevel;
  final DateTime updatedAt;
  int get quantityOnHand =>
      openingQuantity + receivedQuantity - soldQuantity - damagedQuantity;
  int get stockValueMinor => quantityOnHand * unitCostMinor;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'unit': unit,
    'openingQuantity': openingQuantity,
    'receivedQuantity': receivedQuantity,
    'soldQuantity': soldQuantity,
    'damagedQuantity': damagedQuantity,
    'unitCostMinor': unitCostMinor,
    'reorderLevel': reorderLevel,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory StockItem.fromJson(Map<String, Object?> json) => StockItem(
    id: json['id'] as String,
    name: json['name'] as String,
    sku: json['sku'] as String? ?? '',
    unit: json['unit'] as String,
    openingQuantity: json['openingQuantity'] as int,
    receivedQuantity: json['receivedQuantity'] as int,
    soldQuantity: json['soldQuantity'] as int,
    damagedQuantity: json['damagedQuantity'] as int,
    unitCostMinor: json['unitCostMinor'] as int,
    reorderLevel: json['reorderLevel'] as int,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

class StockSummary {
  const StockSummary({
    required this.itemCount,
    required this.unitsOnHand,
    required this.valueMinor,
    required this.lowStock,
    required this.outOfStock,
    required this.fastMovers,
  });
  final int itemCount;
  final int unitsOnHand;
  final int valueMinor;
  final List<StockItem> lowStock;
  final List<StockItem> outOfStock;
  final List<StockItem> fastMovers;
}

class StockAnalyser {
  const StockAnalyser();

  StockSummary analyse(Iterable<StockItem> input) {
    final items = input.toList();
    final ids = <String>{};
    for (final item in items) {
      if (item.id.trim().isEmpty || !ids.add(item.id)) {
        throw const FormatException(
          'Stock item IDs must be present and unique.',
        );
      }
      if (item.name.trim().isEmpty || item.unit.trim().isEmpty) {
        throw const FormatException('Each stock item needs a name and unit.');
      }
      if (item.openingQuantity < 0 ||
          item.receivedQuantity < 0 ||
          item.soldQuantity < 0 ||
          item.damagedQuantity < 0 ||
          item.reorderLevel < 0 ||
          item.unitCostMinor < 0) {
        throw const FormatException(
          'Stock quantities and cost cannot be negative.',
        );
      }
      if (item.soldQuantity + item.damagedQuantity >
          item.openingQuantity + item.receivedQuantity) {
        throw FormatException(
          '${item.name} has more units sold or damaged than were available.',
        );
      }
    }
    final lowStock =
        items.where((v) => v.quantityOnHand <= v.reorderLevel).toList()
          ..sort((a, b) => a.quantityOnHand.compareTo(b.quantityOnHand));
    final outOfStock = items.where((v) => v.quantityOnHand == 0).toList();
    final fastMovers = items.where((v) => v.soldQuantity > 0).toList()
      ..sort((a, b) => b.soldQuantity.compareTo(a.soldQuantity));
    return StockSummary(
      itemCount: items.length,
      unitsOnHand: items.fold(0, (sum, item) => sum + item.quantityOnHand),
      valueMinor: items.fold(0, (sum, item) => sum + item.stockValueMinor),
      lowStock: lowStock,
      outOfStock: outOfStock,
      fastMovers: fastMovers,
    );
  }
}
