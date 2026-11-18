enum ObligationKind { debtor, creditor }

class ObligationRecord {
  const ObligationRecord({
    required this.id,
    required this.kind,
    required this.party,
    required this.description,
    required this.originalMinor,
    required this.settledMinor,
    required this.createdAt,
    this.dueAt,
    this.reference = '',
  });

  final String id;
  final ObligationKind kind;
  final String party;
  final String description;
  final int originalMinor;
  final int settledMinor;
  final DateTime createdAt;
  final DateTime? dueAt;
  final String reference;

  int get outstandingMinor => originalMinor - settledMinor;
  bool get isSettled => outstandingMinor == 0;
  bool isOverdueAt(DateTime date) {
    if (isSettled || dueAt == null) return false;
    final dueKenya = dueAt!.toUtc().add(const Duration(hours: 3));
    final currentKenya = date.toUtc().add(const Duration(hours: 3));
    final dueDay = DateTime.utc(dueKenya.year, dueKenya.month, dueKenya.day);
    final currentDay = DateTime.utc(
      currentKenya.year,
      currentKenya.month,
      currentKenya.day,
    );
    return dueDay.isBefore(currentDay);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'party': party,
    'description': description,
    'originalMinor': originalMinor,
    'settledMinor': settledMinor,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'dueAt': dueAt?.toUtc().toIso8601String(),
    'reference': reference,
  };

  factory ObligationRecord.fromJson(Map<String, Object?> json) =>
      ObligationRecord(
        id: json['id'] as String,
        kind: ObligationKind.values.byName(json['kind'] as String),
        party: json['party'] as String,
        description: json['description'] as String,
        originalMinor: json['originalMinor'] as int,
        settledMinor: json['settledMinor'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        dueAt: json['dueAt'] == null
            ? null
            : DateTime.parse(json['dueAt'] as String),
        reference: json['reference'] as String? ?? '',
      );
}

class ObligationSummary {
  const ObligationSummary({
    required this.debtorOutstandingMinor,
    required this.creditorOutstandingMinor,
    required this.overdueCount,
    required this.openCount,
  });
  final int debtorOutstandingMinor;
  final int creditorOutstandingMinor;
  final int overdueCount;
  final int openCount;
}

class ObligationAnalyser {
  const ObligationAnalyser();

  ObligationSummary analyse(
    Iterable<ObligationRecord> input, {
    DateTime? asOf,
  }) {
    final rows = input.toList();
    final ids = <String>{};
    var debtors = 0;
    var creditors = 0;
    var overdue = 0;
    var open = 0;
    for (final row in rows) {
      if (row.id.trim().isEmpty || !ids.add(row.id)) {
        throw const FormatException('Debt record IDs must be unique.');
      }
      if (row.party.trim().isEmpty || row.description.trim().isEmpty) {
        throw const FormatException('Each record needs a party and a note.');
      }
      if (row.originalMinor <= 0 ||
          row.settledMinor < 0 ||
          row.settledMinor > row.originalMinor) {
        throw const FormatException('Amounts and payments are inconsistent.');
      }
      if (row.kind == ObligationKind.debtor) {
        debtors += row.outstandingMinor;
      } else {
        creditors += row.outstandingMinor;
      }
      if (!row.isSettled) {
        open++;
        if (row.isOverdueAt(asOf ?? DateTime.now())) overdue++;
      }
    }
    return ObligationSummary(
      debtorOutstandingMinor: debtors,
      creditorOutstandingMinor: creditors,
      overdueCount: overdue,
      openCount: open,
    );
  }
}
