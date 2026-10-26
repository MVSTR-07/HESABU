/// Fabricated fixtures only. Integer minor units avoid rounding money in SQLite.
class SamplePayment {
  const SamplePayment(this.receipt, this.occurredAt, this.amountMinor);
  final String receipt;
  final DateTime occurredAt;
  final int amountMinor;
}

List<SamplePayment> generateSamplePayments() => List.generate(
  12,
  (i) => SamplePayment(
    'DEMO-${(i + 1).toString().padLeft(4, '0')}',
    DateTime.utc(2026, 1, i + 1, 7 + i % 5),
    (500 + i * 125) * 100,
  ),
);
