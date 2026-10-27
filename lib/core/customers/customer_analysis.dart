/// Pure local customer analysis. Currency is integer KES cents; no networking.
class CustomerPayment {
  const CustomerPayment({
    required this.id,
    required this.identity,
    required this.name,
    required this.at,
    required this.amount,
    this.phone,
  });
  final String id, identity, name;
  final String? phone;
  final DateTime at;
  final int amount;
  Map<String, dynamic> toJson() => {
    'id': id,
    'identity': identity,
    'name': name,
    'at': at.toUtc().toIso8601String(),
    'amount': amount,
    'phone': phone,
  };
  factory CustomerPayment.fromJson(Map<String, dynamic> v) => CustomerPayment(
    id: v['id'] as String,
    identity: v['identity'] as String,
    name: v['name'] as String,
    at: DateTime.parse(v['at'] as String),
    amount: v['amount'] as int,
    phone: v['phone'] as String?,
  );
}

String? kenyaPhone(String value) {
  var s = value.replaceAll(RegExp(r'[\s()-]'), '');
  if (RegExp(r'^0[17]\d{8}$').hasMatch(s)) s = '+254${s.substring(1)}';
  if (RegExp(r'^254[17]\d{8}$').hasMatch(s)) s = '+$s';
  return RegExp(r'^\+254[17]\d{8}$').hasMatch(s) ? s : null;
}

String identityFor(String name, String? phone) {
  final number = phone == null ? null : kenyaPhone(phone);
  final clean = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (number == null && clean.isEmpty) {
    throw const FormatException(
      'A customer needs a name or a full Kenyan phone number.',
    );
  }
  return number == null ? 'name:$clean' : 'phone:$number';
}

DateTime kenyaDay(DateTime at) {
  final v = at.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(v.year, v.month, v.day);
}

class DropOffConfig {
  const DropOffConfig({this.atRisk = 1.5, this.lost = 3});
  final double atRisk, lost;
  void validate() {
    if (!atRisk.isFinite || !lost.isFinite || atRisk <= 0 || lost <= atRisk) {
      throw const FormatException(
        'Use a positive At Risk multiplier and a larger Lost multiplier.',
      );
    }
  }
}

enum CustomerSegment { champions, loyal, promising, atRisk, lost }

extension CustomerSegmentLabel on CustomerSegment {
  String get label => switch (this) {
    CustomerSegment.champions => 'Champions',
    CustomerSegment.loyal => 'Loyal',
    CustomerSegment.promising => 'Promising',
    CustomerSegment.atRisk => 'At Risk',
    CustomerSegment.lost => 'Lost',
  };
}

double? medianGap(List<DateTime> purchases) {
  final days = purchases.map(kenyaDay).toSet().toList()..sort();
  if (days.length < 2) return null;
  final gaps = [
    for (var i = 1; i < days.length; i++)
      days[i].difference(days[i - 1]).inDays,
  ]..sort();
  final middle = gaps.length ~/ 2;
  return gaps.length.isOdd
      ? gaps[middle].toDouble()
      : (gaps[middle - 1] + gaps[middle]) / 2;
}

CustomerSegment? dropOff(int days, double? gap, DropOffConfig config) {
  config.validate();
  if (gap == null || gap <= 0) return null;
  if (days > gap * config.lost) return CustomerSegment.lost;
  if (days > gap * config.atRisk) return CustomerSegment.atRisk;
  return null;
}

class CustomerStats {
  CustomerStats(
    this.id,
    this.name,
    this.phone,
    this.payments,
    this.daysSince,
    this.gap,
  );
  final String id, name;
  final String? phone;
  final List<CustomerPayment> payments;
  final int daysSince;
  final double? gap;
  int r = 0, f = 0, m = 0;
  CustomerSegment segment = CustomerSegment.promising;
  late final int total = payments.fold(0, (sum, v) => sum + v.amount);
  int get count => payments.length;
  int get average => (total / count).round();
  DateTime get first => payments.first.at;
  DateTime get last => payments.last.at;
  int get priorMonthly =>
      (total /
              ((kenyaDay(last).difference(kenyaDay(first)).inDays + 1) / 30)
                  .clamp(1, double.infinity))
          .round();
}

class RetentionMonth {
  const RetentionMonth(
    this.month,
    this.active,
    this.previous,
    this.retained,
    this.newCustomers,
  );
  final DateTime month;
  final int active, previous, retained, newCustomers;
  double? get retention => previous == 0 ? null : retained / previous;
  double? get churn => previous == 0 ? null : (previous - retained) / previous;
}

class CustomerResults {
  const CustomerResults(this.customers, this.months, this.futureExcluded);
  final List<CustomerStats> customers;
  final List<RetentionMonth> months;
  final int futureExcluded;
  int get total => customers.fold(0, (s, c) => s + c.total);
  double get topFiveShare =>
      total == 0 ? 0 : customers.take(5).fold(0, (s, c) => s + c.total) / total;
  List<CustomerStats> get dropped =>
      customers
          .where(
            (c) =>
                c.segment == CustomerSegment.atRisk ||
                c.segment == CustomerSegment.lost,
          )
          .toList()
        ..sort((a, b) => b.last.compareTo(a.last));
}

String resolveCustomer(String id, Map<String, String> aliases) {
  final seen = <String>{};
  while (aliases.containsKey(id)) {
    if (!seen.add(id)) {
      throw const FormatException(
        'Customer merge links contain a cycle. Undo the last merge.',
      );
    }
    id = aliases[id]!;
  }
  return id;
}

class CustomerAnalyser {
  const CustomerAnalyser();
  CustomerResults analyse(
    List<CustomerPayment> payments, {
    required DateTime asOf,
    DropOffConfig config = const DropOffConfig(),
    Map<String, String> aliases = const {},
  }) {
    config.validate();
    final day = kenyaDay(asOf);
    final grouped = <String, List<CustomerPayment>>{};
    final ids = <String>{};
    var future = 0;
    for (final p in payments) {
      if (p.amount <= 0 || !ids.add(p.id)) continue;
      if (kenyaDay(p.at).isAfter(day)) {
        future++;
        continue;
      }
      grouped
          .putIfAbsent(resolveCustomer(p.identity, aliases), () => [])
          .add(p);
    }
    final customers = <CustomerStats>[];
    for (final e in grouped.entries) {
      final list = e.value..sort((a, b) => a.at.compareTo(b.at));
      final primary =
          list.where((p) => p.identity == e.key).firstOrNull ?? list.first;
      final phone =
          primary.phone ??
          list.map((p) => p.phone).whereType<String>().firstOrNull;
      customers.add(
        CustomerStats(
          e.key,
          primary.name,
          phone,
          list,
          day.difference(kenyaDay(list.last.at)).inDays,
          medianGap(list.map((p) => p.at).toList()),
        ),
      );
    }
    Map<int, int> scores(List<int> all, {bool reverse = false}) {
      all.sort();
      final result = <int, int>{};
      for (var i = 0; i < all.length;) {
        var end = i + 1;
        while (end < all.length && all[end] == all[i]) {
          end++;
        }
        final s = (5 * (i + (end - i) / 2) / all.length).ceil().clamp(1, 5);
        result[all[i]] = reverse ? 6 - s : s;
        i = end;
      }
      return result;
    }

    final recencies = customers.map((c) => c.daysSince).toList(),
        frequencies = customers.map((c) => c.count).toList(),
        amounts = customers.map((c) => c.total).toList();
    final rs = scores(recencies, reverse: true),
        fs = scores(frequencies),
        ms = scores(amounts);
    for (final c in customers) {
      c.r = rs[c.daysSince]!;
      c.f = fs[c.count]!;
      c.m = ms[c.total]!;
      c.segment =
          dropOff(c.daysSince, c.gap, config) ??
          (c.r >= 4 && c.f >= 4 && c.m >= 4
              ? CustomerSegment.champions
              : c.f >= 3
              ? CustomerSegment.loyal
              : CustomerSegment.promising);
    }
    customers.sort((a, b) => b.total.compareTo(a.total));
    final active = <DateTime, Set<String>>{};
    for (final c in customers) {
      for (final p in c.payments) {
        final d = kenyaDay(p.at);
        active.putIfAbsent(DateTime.utc(d.year, d.month), () => {}).add(c.id);
      }
    }
    final months = <RetentionMonth>[];
    if (active.isNotEmpty) {
      final first = active.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      final end = DateTime.utc(day.year, day.month);
      final cutoff = DateTime.utc(day.year, day.month - 23);
      var month = first.isBefore(cutoff) ? cutoff : first;
      while (!month.isAfter(end)) {
        final current = active[month] ?? <String>{};
        final previous =
            active[DateTime.utc(month.year, month.month - 1)] ?? <String>{};
        months.add(
          RetentionMonth(
            month,
            current.length,
            previous.length,
            current.intersection(previous).length,
            current.difference(previous).length,
          ),
        );
        month = DateTime.utc(month.year, month.month + 1);
      }
    }
    return CustomerResults(customers, months, future);
  }
}

Uri customerContactUri(String phone, {String? message}) {
  final number = kenyaPhone(phone);
  if (number == null) {
    throw const FormatException('A full Kenyan phone number is required.');
  }
  return message == null
      ? Uri(scheme: 'tel', path: number)
      : Uri(
          scheme: 'sms',
          path: number,
          query: 'body=${Uri.encodeComponent(message)}',
        );
}

List<CustomerPayment> generateCustomerSamples(DateTime asOf) {
  final day = kenyaDay(asOf);
  final result = <CustomerPayment>[];
  const names = [
    'Wanjiku Demo',
    'Otieno Demo',
    'Amina Demo',
    'Njeri Demo',
    'Brian Demo',
    'Fatuma Demo',
    'Wanjiku Alias Demo',
  ];
  const offsets = [
    [35, 28, 21, 14, 7, 1],
    [70, 63, 56, 49, 42, 35],
    [20, 10, 0],
    [12],
    [60, 40, 20],
    [120, 90, 60],
    [8],
  ];
  for (var i = 0; i < names.length; i++) {
    for (final ago in offsets[i]) {
      final phone = i == 6 ? null : '+25470000000${i + 1}';
      result.add(
        CustomerPayment(
          id: 'sale:sample:$i:$ago',
          identity: identityFor(names[i], phone),
          name: names[i],
          phone: phone,
          at: day.subtract(Duration(days: ago)).add(const Duration(hours: 9)),
          amount: (i == 0 ? 6000 : 1000 + i * 300) * 100,
        ),
      );
    }
  }
  return result;
}
