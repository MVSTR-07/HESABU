/// Plain local sales records and summaries. Money is stored in KES minor units.
class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.soldAt,
    required this.product,
    required this.quantity,
    required this.unitPriceMinor,
    this.customerName = '',
  });

  final String id;
  final DateTime soldAt;
  final String product;
  final int quantity;
  final int unitPriceMinor;
  final String customerName;
  int get totalMinor => quantity * unitPriceMinor;

  Map<String, Object?> toJson() => {
    'id': id,
    'soldAt': soldAt.toUtc().toIso8601String(),
    'product': product,
    'quantity': quantity,
    'unitPriceMinor': unitPriceMinor,
    'customerName': customerName,
  };

  factory SaleRecord.fromJson(Map<String, Object?> json) => SaleRecord(
    id: json['id'] as String,
    soldAt: DateTime.parse(json['soldAt'] as String),
    product: json['product'] as String,
    quantity: json['quantity'] as int,
    unitPriceMinor: json['unitPriceMinor'] as int,
    customerName: json['customerName'] as String? ?? '',
  );
}

class ProductSales {
  const ProductSales(this.product, this.quantity, this.revenueMinor);
  final String product;
  final int quantity;
  final int revenueMinor;
}

class DailySales {
  const DailySales(this.day, this.revenueMinor, this.saleCount);
  final DateTime day;
  final int revenueMinor;
  final int saleCount;
}

class SalesSummary {
  const SalesSummary({
    required this.revenueMinor,
    required this.saleCount,
    required this.unitsSold,
    required this.averageSaleMinor,
    required this.products,
    required this.days,
  });
  final int revenueMinor;
  final int saleCount;
  final int unitsSold;
  final int averageSaleMinor;
  final List<ProductSales> products;
  final List<DailySales> days;
}

class SalesAnalyser {
  const SalesAnalyser();

  SalesSummary analyse(Iterable<SaleRecord> input) {
    final entries = input.toList();
    _validate(entries);
    final productTotals = <String, ({int quantity, int revenue})>{};
    final dailyTotals = <DateTime, ({int revenue, int count})>{};
    var revenue = 0;
    var units = 0;
    for (final sale in entries) {
      final amount = sale.totalMinor;
      revenue += amount;
      units += sale.quantity;
      final key = sale.product.trim();
      final product = productTotals[key];
      productTotals[key] = (
        quantity: (product?.quantity ?? 0) + sale.quantity,
        revenue: (product?.revenue ?? 0) + amount,
      );
      final day = _kenyaDay(sale.soldAt);
      final daily = dailyTotals[day];
      dailyTotals[day] = (
        revenue: (daily?.revenue ?? 0) + amount,
        count: (daily?.count ?? 0) + 1,
      );
    }
    final products =
        productTotals.entries
            .map((e) => ProductSales(e.key, e.value.quantity, e.value.revenue))
            .toList()
          ..sort((a, b) {
            final byRevenue = b.revenueMinor.compareTo(a.revenueMinor);
            return byRevenue != 0 ? byRevenue : a.product.compareTo(b.product);
          });
    final days =
        dailyTotals.entries
            .map((e) => DailySales(e.key, e.value.revenue, e.value.count))
            .toList()
          ..sort((a, b) => a.day.compareTo(b.day));
    return SalesSummary(
      revenueMinor: revenue,
      saleCount: entries.length,
      unitsSold: units,
      averageSaleMinor: entries.isEmpty
          ? 0
          : (revenue / entries.length).round(),
      products: products,
      days: days,
    );
  }

  void _validate(List<SaleRecord> entries) {
    final ids = <String>{};
    for (final sale in entries) {
      if (sale.id.trim().isEmpty || !ids.add(sale.id)) {
        throw const FormatException('Sale IDs must be present and unique.');
      }
      if (sale.product.trim().isEmpty || sale.quantity <= 0) {
        throw const FormatException(
          'Each sale needs a product and a positive quantity.',
        );
      }
      if (sale.unitPriceMinor <= 0) {
        throw const FormatException(
          'Sale prices must be positive KES amounts.',
        );
      }
      if (sale.soldAt.isAfter(
        DateTime.now().toUtc().add(const Duration(days: 1)),
      )) {
        throw const FormatException('Sale dates cannot be in the future.');
      }
    }
  }
}

DateTime _kenyaDay(DateTime at) {
  final kenya = at.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(kenya.year, kenya.month, kenya.day);
}
