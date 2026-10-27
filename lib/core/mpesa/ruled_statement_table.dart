import 'models.dart';
import 'pdf_layout_geometry.dart';

/// One horizontal or vertical vector ruling, in the same top-left coordinate
/// space as StatementWord. No PDF dependency or financial values in this model.
class StatementRule {
  const StatementRule(this.x1, this.y1, this.x2, this.y2);
  final double x1, y1, x2, y2;
  double get left => x1 < x2 ? x1 : x2;
  double get right => x1 > x2 ? x1 : x2;
  double get top => y1 < y2 ? y1 : y2;
  double get bottom => y1 > y2 ? y1 : y2;
  bool get vertical => (x1 - x2).abs() < 0.1 && bottom - top > 2;
  bool get horizontal => (y1 - y2).abs() < 0.1 && right - left > 2;
}

class RuledStatementTable {
  static const unavailableDescription = '[Description unavailable in PDF text]';
  static const _labels = [
    'receipt',
    'completion',
    'details',
    'transaction',
    'paid',
    'withdrawn',
    'balance',
  ];

  /// Null means no complete ruled seven-column table was identified. Once a
  /// grid is identified, invalid cells throw; never silently switch to guesses.
  List<List<String>>? extract(
    List<StatementWord> words,
    List<StatementRule> rules, {
    required int page,
  }) {
    if (rules.isEmpty || words.isEmpty) return null;
    final vertical = rules.where((r) => r.vertical).toList();
    List<double>? columns;
    double? headerY;
    for (final receipt in words.where(
      (w) => _normal(w.text).startsWith('receipt'),
    )) {
      final band = words
          .where((w) => (w.top - receipt.top).abs() < receipt.height * 2.5)
          .toList();
      final labels = <StatementWord>[];
      for (final label in _labels) {
        final candidates =
            band.where((w) => _normal(w.text).startsWith(label)).toList()
              ..sort((a, b) => a.left.compareTo(b.left));
        if (candidates.isEmpty) break;
        labels.add(candidates.first);
      }
      if (labels.length != 7) continue;
      final y =
          labels.map((w) => (w.top + w.bottom) / 2).reduce((a, b) => a + b) / 7;
      final xs = _cluster(
        vertical
            .where((r) => r.top <= y + .1 && r.bottom >= y - .1)
            .map((r) => (r.left + r.right) / 2)
            .toList(),
      );
      final center = (labels.first.left + labels.first.right) / 2;
      final start = xs.indexWhere((x) => x > center) - 1;
      if (start < 0 || start + 7 >= xs.length) continue;
      final candidate = xs.sublist(start, start + 8);
      if (!List.generate(7, (i) => i).every((i) {
        final x = (labels[i].left + labels[i].right) / 2;
        return x > candidate[i] && x < candidate[i + 1];
      })) {
        continue;
      }
      columns = candidate;
      headerY = y;
      break;
    }
    if (columns == null || headerY == null) return null;
    final xs = columns;
    final horizontal = rules
        .where((r) => r.horizontal && r.right >= xs.first && r.left <= xs.last)
        .toList();
    final groups = <List<StatementRule>>[];
    horizontal.sort((a, b) => a.top.compareTo(b.top));
    for (final rule in horizontal) {
      if (groups.isEmpty || (rule.top - groups.last.first.top).abs() > .7) {
        groups.add([rule]);
      } else {
        groups.last.add(rule);
      }
    }
    final ys = <double>[];
    for (final group in groups) {
      final intervals =
          group
              .map(
                (r) => (
                  r.left < xs.first ? xs.first : r.left,
                  r.right > xs.last ? xs.last : r.right,
                ),
              )
              .toList()
            ..sort((a, b) => a.$1.compareTo(b.$1));
      double? start;
      var end = 0.0, covered = 0.0;
      for (final span in intervals) {
        if (start == null) {
          start = span.$1;
          end = span.$2;
        } else if (span.$1 <= end + 1) {
          if (span.$2 > end) end = span.$2;
        } else {
          covered += end - start;
          start = span.$1;
          end = span.$2;
        }
      }
      if (start != null) covered += end - start;
      if (covered >= (xs.last - xs.first) * .98) {
        ys.add(group.map((r) => r.top).reduce((a, b) => a + b) / group.length);
      }
    }
    final headerBottom = ys.indexWhere((y) => y > headerY!);
    if (headerBottom < 0) return null;
    final rows = <List<String>>[];
    double? tableEnd;
    for (var i = headerBottom; i + 1 < ys.length; i++) {
      final top = ys[i], bottom = ys[i + 1], middle = (top + bottom) / 2;
      final closed = xs.every(
        (x) => vertical.any(
          (r) =>
              ((r.left + r.right) / 2 - x).abs() < .9 &&
              r.top <= middle + .1 &&
              r.bottom >= middle - .1,
        ),
      );
      if (!closed) {
        tableEnd = top;
        break;
      }
      final rowWords = words.where((w) {
        final x = (w.left + w.right) / 2, y = (w.top + w.bottom) / 2;
        return x >= xs.first && x < xs.last && y >= top && y < bottom;
      }).toList();
      if (rowWords.isEmpty) continue;
      final cells = List.generate(7, (_) => <StatementWord>[]);
      for (final word in rowWords) {
        final x = (word.left + word.right) / 2;
        final col = xs.indexWhere((v) => v > x) - 1;
        if (col >= 0 && col < 7) cells[col].add(word);
      }
      final values = cells.map(_cellText).toList();
      if (!RegExp(r'^[A-Z0-9-]{6,20}$').hasMatch(values[0]) ||
          values[1].isEmpty ||
          values[3].isEmpty ||
          values[6].isEmpty) {
        throw StatementImportException(
          'PDF layout diagnostic [RULED_CELLS]: page $page, row ${rows.length + 1}. Required receipt, completion time, status or balance cell is unreadable. No partial import was saved.',
        );
      }
      if (values[2].isEmpty) {
        values[2] = unavailableDescription;
      }
      rows.add(values);
      tableEnd = bottom;
    }
    if (rows.isEmpty) return null;
    // A separated footer is allowed, but never drop another transaction below
    // an incomplete border. Only shapes are checked; no values enter errors.
    final below = words
        .where(
          (w) =>
              tableEnd != null &&
              w.top >= tableEnd &&
              (w.left + w.right) / 2 >= xs.first &&
              (w.left + w.right) / 2 < xs.last,
        )
        .toList();
    final receipts = below.where(
      (w) =>
          (w.left + w.right) / 2 < xs[1] &&
          RegExp(r'^[A-Z0-9]{8,15}$').hasMatch(w.text),
    );
    if (receipts.any(
      (r) => below.any(
        (w) =>
            (w.top - r.top).abs() < r.height &&
            (w.left + w.right) / 2 >= xs[1] &&
            (w.left + w.right) / 2 < xs[2] &&
            RegExp(r'\d{2,4}[-/]\d{2}').hasMatch(w.text),
      ),
    )) {
      throw StatementImportException(
        'PDF layout diagnostic [RULED_BOUNDS]: page $page. Transaction-shaped text lies outside the closed table grid. No partial import was saved.',
      );
    }
    return rows;
  }

  static String _cellText(List<StatementWord> words) {
    final lines = <List<StatementWord>>[];
    words.sort((a, b) => a.top.compareTo(b.top));
    for (final word in words) {
      final height = lines.isEmpty
          ? word.height
          : lines.last
                .map((w) => w.height)
                .fold(word.height, (a, b) => a > b ? a : b);
      if (lines.isEmpty ||
          (word.top - lines.last.first.top).abs() > height * .8) {
        lines.add([word]);
      } else {
        lines.last.add(word);
      }
    }
    for (final line in lines) {
      line.sort((a, b) => a.left.compareTo(b.left));
    }
    return lines.expand((line) => line.map((w) => w.text)).join(' ').trim();
  }

  static String _normal(String s) =>
      s.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  static List<double> _cluster(List<double> points) {
    points.sort();
    final groups = <List<double>>[];
    for (final p in points) {
      if (groups.isEmpty || p - groups.last.last > .7) {
        groups.add([p]);
      } else {
        groups.last.add(p);
      }
    }
    return groups.map((g) => g.reduce((a, b) => a + b) / g.length).toList();
  }
}
