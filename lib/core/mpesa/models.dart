enum MpesaType {
  customerPayment,
  sentMoney,
  withdrawal,
  airtime,
  paybillTill,
  fee,
  fuliza,
  reversal,
  unknown;

  String get label => switch (this) {
    customerPayment => 'Customer payment received',
    sentMoney => 'Sent money',
    withdrawal => 'Withdrawal',
    airtime => 'Airtime',
    paybillTill => 'Paybill / Till',
    fee => 'Fees / charges',
    fuliza => 'Fuliza',
    reversal => 'Reversal',
    unknown => 'Unclassified',
  };
}

enum FulizaRole { draw, repayment, cost, unknown }

/// Money is stored in integer Kenyan cents; date/time is always UTC.
class MpesaTransaction {
  const MpesaTransaction({
    required this.row,
    required this.at,
    required this.receipt,
    required this.details,
    required this.paidIn,
    required this.withdrawn,
    required this.balance,
    this.type = MpesaType.unknown,
    this.counterparty,
    this.fulizaRole,
    this.fulizaCost = 0,
  });
  final int row;
  final DateTime at;
  final String receipt;
  final String details;
  final int paidIn, withdrawn;
  final int? balance;
  final MpesaType type;
  final String? counterparty;
  final FulizaRole? fulizaRole;
  final int fulizaCost;
  int get amount => paidIn > withdrawn ? paidIn : withdrawn;
  DateTime get kenyaTime => at.toUtc().add(const Duration(hours: 3));
  String get fingerprint => [
    receipt.toUpperCase(),
    at.toUtc().toIso8601String(),
    details.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim(),
    paidIn,
    withdrawn,
    balance,
  ].join('|');

  MpesaTransaction classified(
    MpesaType type, {
    String? party,
    FulizaRole? role,
    int cost = 0,
  }) => MpesaTransaction(
    row: row,
    at: at,
    receipt: receipt,
    details: details,
    paidIn: paidIn,
    withdrawn: withdrawn,
    balance: balance,
    type: type,
    counterparty: party,
    fulizaRole: role,
    fulizaCost: cost,
  );

  Map<String, dynamic> toJson() => {
    'row': row,
    'at': at.toUtc().toIso8601String(),
    'receipt': receipt,
    'details': details,
    'in': paidIn,
    'out': withdrawn,
    'balance': balance,
    'type': type.name,
    'party': counterparty,
    'fulizaRole': fulizaRole?.name,
    'fulizaCost': fulizaCost,
  };
  factory MpesaTransaction.fromJson(Map<String, dynamic> j) => MpesaTransaction(
    row: j['row'] as int,
    at: DateTime.parse(j['at'] as String),
    receipt: j['receipt'] as String,
    details: j['details'] as String,
    paidIn: j['in'] as int,
    withdrawn: j['out'] as int,
    balance: j['balance'] as int?,
    type: MpesaType.values.byName(j['type'] as String),
    counterparty: j['party'] as String?,
    fulizaRole: j['fulizaRole'] == null
        ? null
        : FulizaRole.values.byName(j['fulizaRole'] as String),
    fulizaCost: j['fulizaCost'] as int? ?? 0,
  );
}

class ParsedStatement {
  const ParsedStatement(this.transactions, [this.warnings = const []]);
  final List<MpesaTransaction> transactions;
  final List<String> warnings;
}

/// These safe messages contain row numbers, never statement lines/passwords.
class StatementImportException implements Exception {
  const StatementImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AnomalyThresholds {
  const AnomalyThresholds({
    this.largeAmount = 10000000,
    this.spikeMultiplier = 3,
    this.minimumSpikeAmount = 100000,
    this.minimumBaseline = 3,
  });
  final int largeAmount, minimumSpikeAmount, minimumBaseline;
  final double spikeMultiplier;
  void validate() {
    if (largeAmount <= 0 ||
        minimumSpikeAmount < 0 ||
        !spikeMultiplier.isFinite ||
        spikeMultiplier <= 1 ||
        minimumBaseline < 3 ||
        minimumBaseline > 1000) {
      throw const StatementImportException(
        'Use a positive large-payment threshold, a spike multiplier above 1, and 3–1000 baseline payments.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'largeAmount': largeAmount,
    'spikeMultiplier': spikeMultiplier,
    'minimumSpikeAmount': minimumSpikeAmount,
    'minimumBaseline': minimumBaseline,
  };
  factory AnomalyThresholds.fromJson(Map<String, dynamic> j) =>
      AnomalyThresholds(
        largeAmount: j['largeAmount'] as int,
        spikeMultiplier: (j['spikeMultiplier'] as num).toDouble(),
        minimumSpikeAmount: j['minimumSpikeAmount'] as int,
        minimumBaseline: j['minimumBaseline'] as int,
      );
}

enum AnomalyKind { duplicate, receiptConflict, spike, largeOneOff }

class MpesaAnomaly {
  const MpesaAnomaly(this.kind, this.row, this.message);
  final AnomalyKind kind;
  final int row;
  final String message;
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'row': row,
    'message': message,
  };
  factory MpesaAnomaly.fromJson(Map<String, dynamic> j) => MpesaAnomaly(
    AnomalyKind.values.byName(j['kind'] as String),
    j['row'] as int,
    j['message'] as String,
  );
}

class CashPeriod {
  const CashPeriod(this.key, this.moneyIn, this.moneyOut, this.count);
  final String key;
  final int moneyIn, moneyOut, count;
  int get net => moneyIn - moneyOut;
  Map<String, dynamic> toJson() => {
    'key': key,
    'in': moneyIn,
    'out': moneyOut,
    'count': count,
  };
  factory CashPeriod.fromJson(Map<String, dynamic> j) => CashPeriod(
    j['key'] as String,
    j['in'] as int,
    j['out'] as int,
    j['count'] as int,
  );
}

class RankedParty {
  const RankedParty(this.name, this.amount, this.count);
  final String name;
  final int amount, count;
  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'count': count,
  };
  factory RankedParty.fromJson(Map<String, dynamic> j) =>
      RankedParty(j['name'] as String, j['amount'] as int, j['count'] as int);
}

class BalancePoint {
  const BalancePoint(this.at, this.balance);
  final DateTime at;
  final int balance;
  Map<String, dynamic> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'balance': balance,
  };
  factory BalancePoint.fromJson(Map<String, dynamic> j) =>
      BalancePoint(DateTime.parse(j['at'] as String), j['balance'] as int);
}

class MpesaResults {
  const MpesaResults({
    required this.moneyIn,
    required this.moneyOut,
    required this.fees,
    required this.fulizaCost,
    required this.uniqueCount,
    required this.duplicateRows,
    required this.anomalies,
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.senders,
    required this.receivers,
    required this.hours,
    required this.weekdays,
    required this.balances,
    required this.thresholds,
  });
  final int moneyIn, moneyOut, fees, fulizaCost, uniqueCount;
  int get net => moneyIn - moneyOut;
  final Set<int> duplicateRows;
  final List<MpesaAnomaly> anomalies;
  final List<CashPeriod> daily, weekly, monthly;
  final List<RankedParty> senders, receivers;
  final List<int> hours, weekdays;
  final List<BalancePoint> balances;
  final AnomalyThresholds thresholds;
  Map<String, dynamic> toJson() => {
    'in': moneyIn,
    'out': moneyOut,
    'fees': fees,
    'fulizaCost': fulizaCost,
    'uniqueCount': uniqueCount,
    'duplicateRows': duplicateRows.toList(),
    'anomalies': anomalies.map((v) => v.toJson()).toList(),
    'daily': daily.map((v) => v.toJson()).toList(),
    'weekly': weekly.map((v) => v.toJson()).toList(),
    'monthly': monthly.map((v) => v.toJson()).toList(),
    'senders': senders.map((v) => v.toJson()).toList(),
    'receivers': receivers.map((v) => v.toJson()).toList(),
    'hours': hours,
    'weekdays': weekdays,
    'balances': balances.map((v) => v.toJson()).toList(),
    'thresholds': thresholds.toJson(),
  };
  factory MpesaResults.fromJson(Map<String, dynamic> j) => MpesaResults(
    moneyIn: j['in'] as int,
    moneyOut: j['out'] as int,
    fees: j['fees'] as int,
    fulizaCost: j['fulizaCost'] as int,
    uniqueCount: j['uniqueCount'] as int,
    duplicateRows: (j['duplicateRows'] as List).cast<int>().toSet(),
    anomalies: (j['anomalies'] as List)
        .map((v) => MpesaAnomaly.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    daily: _periods(j['daily']),
    weekly: _periods(j['weekly']),
    monthly: _periods(j['monthly']),
    senders: _parties(j['senders']),
    receivers: _parties(j['receivers']),
    hours: (j['hours'] as List).cast<int>(),
    weekdays: (j['weekdays'] as List).cast<int>(),
    balances: (j['balances'] as List)
        .map((v) => BalancePoint.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    thresholds: AnomalyThresholds.fromJson(
      Map<String, dynamic>.from(j['thresholds'] as Map),
    ),
  );
  static List<CashPeriod> _periods(dynamic v) => (v as List)
      .map((e) => CashPeriod.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  static List<RankedParty> _parties(dynamic v) => (v as List)
      .map((e) => RankedParty.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

class StatementSummary {
  const StatementSummary(this.id, this.label, this.format, this.importedAt);
  final int id;
  final String label, format;
  final DateTime importedAt;
}

class StoredStatement {
  const StoredStatement({
    required this.id,
    required this.label,
    required this.format,
    required this.importedAt,
    required this.transactions,
    required this.results,
    this.warnings = const [],
  });
  final int id;
  final String label, format;
  final DateTime importedAt;
  final List<MpesaTransaction> transactions;
  final MpesaResults results;
  final List<String> warnings;
}
