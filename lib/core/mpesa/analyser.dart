import 'anomaly_rules.dart';
import 'classifier.dart';
import 'models.dart';

class MpesaAnalyser {
  const MpesaAnalyser();
  MpesaResults analyse(
    List<MpesaTransaction> input, {
    AnomalyThresholds thresholds = const AnomalyThresholds(),
  }) {
    thresholds.validate();
    final classified = input.map(const MpesaClassifier().classify).toList();
    final scan = const MpesaAnomalyRules().scan(classified, thresholds);
    final txs = [...scan.unique]
      ..sort((a, b) {
        final order = a.at.compareTo(b.at);
        return order == 0 ? a.row.compareTo(b.row) : order;
      });
    var moneyIn = 0, moneyOut = 0, fees = 0, fuliza = 0;
    final days = <String, List<int>>{},
        weeks = <String, List<int>>{},
        months = <String, List<int>>{};
    final senders = <String, List<int>>{}, receivers = <String, List<int>>{};
    final hours = List.filled(24, 0), weekdays = List.filled(7, 0);
    final balances = <BalancePoint>[];
    for (final tx in txs) {
      moneyIn += tx.paidIn;
      moneyOut += tx.withdrawn;
      if (tx.type == MpesaType.fee) fees += tx.withdrawn;
      fuliza += tx.fulizaCost;
      final local = tx.kenyaTime;
      final date = DateTime.utc(local.year, local.month, local.day);
      _add(days, _key(date), tx);
      _add(weeks, _key(date.subtract(Duration(days: date.weekday - 1))), tx);
      _add(months, _key(date).substring(0, 7), tx);
      hours[local.hour]++;
      weekdays[local.weekday - 1]++;
      if (tx.balance != null) balances.add(BalancePoint(tx.at, tx.balance!));
      if (tx.counterparty != null &&
          tx.type == MpesaType.customerPayment &&
          tx.paidIn > 0) {
        _rank(senders, tx.counterparty!, tx.paidIn);
      }
      if (tx.counterparty != null &&
          tx.withdrawn > 0 &&
          [
            MpesaType.sentMoney,
            MpesaType.paybillTill,
            MpesaType.withdrawal,
          ].contains(tx.type)) {
        _rank(receivers, tx.counterparty!, tx.withdrawn);
      }
    }
    return MpesaResults(
      moneyIn: moneyIn,
      moneyOut: moneyOut,
      fees: fees + fuliza,
      fulizaCost: fuliza,
      uniqueCount: txs.length,
      duplicateRows: scan.duplicateRows,
      anomalies: scan.flags,
      daily: _periods(days),
      weekly: _periods(weeks),
      monthly: _periods(months),
      senders: _ranked(senders),
      receivers: _ranked(receivers),
      hours: hours,
      weekdays: weekdays,
      balances: balances,
      thresholds: thresholds,
    );
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  void _add(Map<String, List<int>> map, String key, MpesaTransaction tx) {
    final value = map.putIfAbsent(key, () => [0, 0, 0]);
    value[0] += tx.paidIn;
    value[1] += tx.withdrawn;
    value[2]++;
  }

  void _rank(Map<String, List<int>> map, String name, int amount) {
    final v = map.putIfAbsent(name, () => [0, 0]);
    v[0] += amount;
    v[1]++;
  }

  List<CashPeriod> _periods(Map<String, List<int>> map) =>
      (map.keys.toList()..sort())
          .map((k) => CashPeriod(k, map[k]![0], map[k]![1], map[k]![2]))
          .toList();
  List<RankedParty> _ranked(Map<String, List<int>> map) =>
      map.entries
          .map((e) => RankedParty(e.key, e.value[0], e.value[1]))
          .toList()
        ..sort((a, b) {
          final order = b.amount.compareTo(a.amount);
          return order == 0 ? a.name.compareTo(b.name) : order;
        });
}
