import 'package:intl/intl.dart';

String formatKes(int minorUnits) => NumberFormat.currency(
  locale: 'en_KE',
  symbol: 'KES ',
  decimalDigits: 2,
).format(minorUnits / 100);

/// Stored UTC timestamps are shown in Kenya time, independently of device zone.
String formatKenyaDate(DateTime instant) =>
    DateFormat('dd/MM/yyyy')
        .format(instant.toUtc().add(const Duration(hours: 3)));

String formatKenyaDateTime(DateTime instant) =>
    DateFormat('dd/MM/yyyy HH:mm:ss')
        .format(instant.toUtc().add(const Duration(hours: 3)));
