/// Plain local expenses. Amounts are integer KES minor units, never doubles.
class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.spentAt,
    required this.category,
    required this.description,
    required this.amountMinor,
    this.payee = '',
  });

  final String id;
  final DateTime spentAt;
  final String category;
  final String description;
  final int amountMinor;
  final String payee;

  Map<String, Object?> toJson() => {
    'id': id,
    'spentAt': spentAt.toUtc().toIso8601String(),
    'category': category,
    'description': description,
    'amountMinor': amountMinor,
    'payee': payee,
  };

  factory ExpenseRecord.fromJson(Map<String, Object?> json) => ExpenseRecord(
    id: json['id'] as String,
    spentAt: DateTime.parse(json['spentAt'] as String),
    category: json['category'] as String,
    description: json['description'] as String,
    amountMinor: json['amountMinor'] as int,
    payee: json['payee'] as String? ?? '',
  );
}

class ExpenseCategoryTotal {
  const ExpenseCategoryTotal(this.category, this.amountMinor, this.count);
  final String category;
  final int amountMinor;
  final int count;
}

class MonthlyExpenseTotal {
  const MonthlyExpenseTotal(this.month, this.amountMinor);
  final DateTime month;
  final int amountMinor;
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.totalMinor,
    required this.count,
    required this.averageMinor,
    required this.categories,
    required this.months,
    required this.largest,
  });
  final int totalMinor;
  final int count;
  final int averageMinor;
  final List<ExpenseCategoryTotal> categories;
  final List<MonthlyExpenseTotal> months;
  final ExpenseRecord? largest;
}

class ExpenseAnalyser {
  const ExpenseAnalyser();

  ExpenseSummary analyse(Iterable<ExpenseRecord> input) {
    final entries = input.toList();
    final ids = <String>{};
    final categoryTotals = <String, ({int amount, int count})>{};
    final monthTotals = <DateTime, int>{};
    var total = 0;
    ExpenseRecord? largest;
    for (final expense in entries) {
      if (expense.id.trim().isEmpty || !ids.add(expense.id)) {
        throw const FormatException('Expense IDs must be present and unique.');
      }
      if (expense.category.trim().isEmpty ||
          expense.description.trim().isEmpty) {
        throw const FormatException(
          'Each expense needs a category and description.',
        );
      }
      if (expense.amountMinor <= 0) {
        throw const FormatException('Expense amounts must be positive KES.');
      }
      if (expense.spentAt.isAfter(
        DateTime.now().toUtc().add(const Duration(days: 1)),
      )) {
        throw const FormatException('Expense dates cannot be in the future.');
      }
      total += expense.amountMinor;
      largest = largest == null || expense.amountMinor > largest.amountMinor
          ? expense
          : largest;
      final category = expense.category.trim();
      final oldCategory = categoryTotals[category];
      categoryTotals[category] = (
        amount: (oldCategory?.amount ?? 0) + expense.amountMinor,
        count: (oldCategory?.count ?? 0) + 1,
      );
      final kenya = expense.spentAt.toUtc().add(const Duration(hours: 3));
      final month = DateTime.utc(kenya.year, kenya.month);
      monthTotals.update(
        month,
        (value) => value + expense.amountMinor,
        ifAbsent: () => expense.amountMinor,
      );
    }
    final categories =
        categoryTotals.entries
            .map(
              (e) => ExpenseCategoryTotal(e.key, e.value.amount, e.value.count),
            )
            .toList()
          ..sort((a, b) {
            final byAmount = b.amountMinor.compareTo(a.amountMinor);
            return byAmount != 0 ? byAmount : a.category.compareTo(b.category);
          });
    final months =
        monthTotals.entries
            .map((e) => MonthlyExpenseTotal(e.key, e.value))
            .toList()
          ..sort((a, b) => a.month.compareTo(b.month));
    return ExpenseSummary(
      totalMinor: total,
      count: entries.length,
      averageMinor: entries.isEmpty ? 0 : (total / entries.length).round(),
      categories: categories,
      months: months,
      largest: largest,
    );
  }
}
