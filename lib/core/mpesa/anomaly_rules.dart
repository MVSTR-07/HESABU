import 'models.dart';

class AnomalyScan {
  const AnomalyScan(this.unique, this.duplicateRows, this.flags);
  final List<MpesaTransaction> unique;
  final Set<int> duplicateRows;
  final List<MpesaAnomaly> flags;
}

class MpesaAnomalyRules {
  const MpesaAnomalyRules();
  AnomalyScan scan(
    List<MpesaTransaction> transactions,
    AnomalyThresholds thresholds,
  ) {
    thresholds.validate();
    final fingerprints = <String>{};
    final receipts = <String>{};
    final unique = <MpesaTransaction>[];
    final duplicates = <int>{};
    final flags = <MpesaAnomaly>[];
    for (final tx in transactions) {
      if (!fingerprints.add(tx.fingerprint)) {
        duplicates.add(tx.row);
        flags.add(
          MpesaAnomaly(
            AnomalyKind.duplicate,
            tx.row,
            'Exact repeated transaction; excluded from totals and charts.',
          ),
        );
        continue;
      }
      if (!receipts.add(tx.receipt.toUpperCase())) {
        // A fee can legitimately share its parent's receipt. Do not discard it.
        flags.add(
          MpesaAnomaly(
            AnomalyKind.receiptConflict,
            tx.row,
            'Receipt appears on different rows. Review; both distinct rows remain in totals.',
          ),
        );
      }
      unique.add(tx);
    }
    final incoming =
        unique.where((v) => v.paidIn > 0).map((v) => v.paidIn).toList()..sort();
    final outgoing =
        unique.where((v) => v.withdrawn > 0).map((v) => v.withdrawn).toList()
          ..sort();
    for (final tx in unique) {
      if (tx.amount >= thresholds.largeAmount) {
        flags.add(
          MpesaAnomaly(
            AnomalyKind.largeOneOff,
            tx.row,
            'Transaction meets the configured large-payment threshold.',
          ),
        );
      }
      final baseline = tx.paidIn > 0 ? incoming : outgoing;
      if (tx.amount < thresholds.minimumSpikeAmount ||
          baseline.length - 1 < thresholds.minimumBaseline) {
        continue;
      }
      final median = _medianWithoutOne(baseline, tx.amount);
      if (median > 0 && tx.amount > median * thresholds.spikeMultiplier) {
        flags.add(
          MpesaAnomaly(
            AnomalyKind.spike,
            tx.row,
            'More than ${thresholds.spikeMultiplier}× the median of the other ${tx.paidIn > 0 ? 'incoming' : 'outgoing'} payments.',
          ),
        );
      }
    }
    return AnomalyScan(unique, duplicates, flags);
  }

  /// O(log n), avoiding an O(n²) copy/sort for large statements. Exclude one
  /// occurrence of this amount; equal-valued payments remain in the baseline.
  double _medianWithoutOne(List<int> sorted, int amount) {
    var lo = 0, hi = sorted.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (sorted[mid] < amount) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final skipped = lo;
    int at(int i) => sorted[i >= skipped ? i + 1 : i];
    final count = sorted.length - 1;
    return count.isOdd
        ? at(count ~/ 2).toDouble()
        : (at(count ~/ 2 - 1) + at(count ~/ 2)) / 2;
  }
}
