import 'models.dart';
import 'pdf_layout_geometry.dart';
import 'ruled_statement_table.dart';
export 'pdf_layout_geometry.dart';

/// Reconstructs cells before whitespace is flattened. Empty monetary columns
/// stay empty; amounts are never assigned a direction from description text.
class PdfStatementTable {
  static const marker = 'HESABU_LOCAL_POSITIONED_TABLE_V1\n';
  static const header =
      'Receipt No.,Completion Time,Details,Transaction Status,Paid In,Withdrawn,Balance';
  final List<List<String>> _rows = [];
  bool foundTable = false;
  int _pageCount = 0;
  int get rowCount => _rows.length;

  void addPage(
    List<StatementWord> words, {
    List<StatementRule> rules = const [],
  }) {
    final pageNumber = ++_pageCount;
    if (words.isEmpty) return;
    final ruled = RuledStatementTable().extract(words, rules, page: pageNumber);
    if (ruled != null) {
      foundTable = true;
      _rows.addAll(ruled);
      if (_rows.length > 50000) {
        throw const StatementImportException(
          'Statement exceeds 50,000 rows. Import a shorter date range.',
        );
      }
      return;
    }
    final lines = _lines(words);
    List<StatementWord>? labels;
    double headerTop = 0;
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].any((w) => _normal(w.text).startsWith('receipt'))) continue;
      final h = lines[i].map((w) => w.height).reduce((a, b) => a > b ? a : b);
      final band = words
          .where(
            (w) =>
                w.top >= lines[i].first.top - h / 2 &&
                w.top <= lines[i].first.top + h * 2.5,
          )
          .toList();
      final keys = [
        'receipt',
        'completion',
        'details',
        'transaction',
        'paid',
        'withdrawn',
        'balance',
      ];
      final selected = <StatementWord>[];
      for (final key in keys) {
        final matches =
            band.where((w) => _normal(w.text).startsWith(key)).toList()
              ..sort((a, b) => a.top.compareTo(b.top));
        if (matches.isEmpty && key == 'transaction') {
          matches.addAll(band.where((w) => _normal(w.text) == 'status'));
        }
        if (matches.isEmpty) break;
        selected.add(matches.first);
      }
      if (selected.length == 7) {
        labels = selected;
        headerTop = selected
            .map((w) => w.bottom)
            .reduce((a, b) => a > b ? a : b);
        break;
      }
    }
    if (labels == null) {
      if (foundTable &&
          words.any((w) => RegExp(r'^[A-Z0-9]{8,15}$').hasMatch(w.text))) {
        throw StatementImportException(
          'PDF layout diagnostic [HEADERS]: page $pageNumber. Column headers could not be located. No partial import was saved. This diagnostic contains no transaction values.',
        );
      }
      return;
    }
    foundTable = true;
    for (var i = 1; i < labels.length; i++) {
      if (labels[i].left <= labels[i - 1].right) {
        throw StatementImportException(
          'PDF layout diagnostic [COLUMN_ORDER]: page $pageNumber. Conflicting columns: ${_columnNames[i - 1]}, ${_columnNames[i]}. No partial import was saved. This diagnostic contains no transaction values.',
        );
      }
    }
    final boundaries = <double>[
      labels[1].left - 2,
      labels[2].left - 2,
      labels[3].left - 2,
      (labels[3].left + labels[3].right + labels[4].left + labels[4].right) / 4,
      (labels[4].left + labels[4].right + labels[5].left + labels[5].right) / 4,
      (labels[5].left + labels[5].right + labels[6].left + labels[6].right) / 4,
    ];
    // A centred Details heading is NOT the cell's left edge. Measure the
    // actual date/time text extent instead; never strip words from a date
    // after extraction or guess an amount's direction from its description.
    final dateParts = words
        .where(
          (w) =>
              w.top > headerTop &&
              (w.left + w.right) / 2 >= boundaries[0] &&
              (w.left + w.right) / 2 < boundaries[1] &&
              RegExp(
                r'^(?:\d{4}-\d{2}-\d{2}|\d{2}/\d{2}/\d{4})(?:[T ]\d{1,2}:\d{2}(?::\d{2})?)?$|^\d{1,2}:\d{2}(?::\d{2})?$',
              ).hasMatch(w.text),
        )
        .toList();
    final dates = dateParts
        .where((w) => RegExp(r'^\d{2,4}[-/]\d{2}').hasMatch(w.text))
        .toList();
    final completionParts = <StatementWord>[];
    if (dates.isNotEmpty) {
      // Completion dates align at the first date-text position. A date quoted
      // later in Details must not move this column edge for the entire page.
      final left = dates.map((w) => w.left).reduce((a, b) => a < b ? a : b);
      final aligned = dates.where((w) => (w.left - left).abs() <= 2).toList();
      completionParts.addAll(aligned);
      if (!aligned.every((w) => w.text.contains(':'))) {
        final right = aligned
            .map((w) => w.right)
            .reduce((a, b) => a > b ? a : b);
        final height = aligned
            .map((w) => w.height)
            .reduce((a, b) => a > b ? a : b);
        completionParts.addAll(
          dateParts.where(
            (w) =>
                RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?$').hasMatch(w.text) &&
                w.left >= left - 2 &&
                w.left <= right + height * 1.5,
          ),
        );
      }
    }
    if (completionParts.any((w) => w.text.contains(':'))) {
      final end =
          completionParts.map((w) => w.right).reduce((a, b) => a > b ? a : b) +
          1;
      if (end > boundaries[0] && end < boundaries[2]) boundaries[1] = end;
    }
    int column(StatementWord w) {
      final center = (w.left + w.right) / 2;
      final index = boundaries.indexWhere((edge) => center < edge);
      return index < 0 ? 6 : index;
    }

    var body = words.where((w) => w.top > headerTop).toList();
    // Find footer boundaries BEFORE grouping receipt anchors. Only fixed footer
    // phrases starting in the leftmost column qualify; merchant descriptions
    // elsewhere in the table must remain transaction data.
    final bodyLines = _lines(body);
    for (var lineIndex = 0; lineIndex < bodyLines.length; lineIndex++) {
      final line = bodyLines[lineIndex];
      if (column(line.first) != 0 ||
          !_footer.hasMatch(line.map((w) => w.text).join(' '))) {
        continue;
      }
      final footerTop = line.map((w) => w.top).reduce((a, b) => a < b ? a : b);
      final laterRows = bodyLines
          .skip(lineIndex)
          .any(
            (candidate) =>
                candidate.any(
                  (w) =>
                      column(w) == 0 &&
                      RegExp(r'^[A-Z0-9]{8,15}$').hasMatch(w.text),
                ) &&
                candidate.any(
                  (w) =>
                      column(w) == 1 &&
                      RegExp(r'\d{2,4}[-/]\d{2}').hasMatch(w.text),
                ),
          );
      if (laterRows) {
        throw StatementImportException(
          'PDF layout diagnostic [FOOTER_BOUNDS]: page $pageNumber. Transaction-shaped text follows a footer marker. No partial import was saved. This diagnostic contains no transaction values.',
        );
      }
      body = body.where((w) => w.top < footerTop).toList();
      break;
    }
    final anchors =
        body
            .where(
              (w) =>
                  column(w) == 0 &&
                  RegExp(r'^[A-Z0-9]{8,15}$').hasMatch(w.text),
            )
            .toList()
          ..sort((a, b) => a.top.compareTo(b.top));
    for (var i = 0; i < anchors.length; i++) {
      final anchor = anchors[i];
      // Glyph tops vary with capital letters, ascenders and different fonts.
      // Compare lower edges instead, allowing a shared baseline even when the
      // description's glyph top sits above the receipt's top. Apply the SAME
      // boundary to adjacent rows so words cannot be duplicated between them.
      final start = anchor.bottom - anchor.height * 0.9;
      final end = i + 1 < anchors.length
          ? anchors[i + 1].bottom - anchors[i + 1].height * 0.9
          : double.infinity;
      final rowWords = body
          .where((w) => w.bottom >= start && w.bottom < end)
          .toList();
      final rowLines = _lines(rowWords);
      final cells = List.generate(7, (_) => <String>[]);
      double lastBottom = anchor.bottom;
      for (final line in rowLines) {
        if (line.first.top - lastBottom > anchor.height * 3) break;
        for (final word in line) {
          cells[column(word)].add(word.text);
        }
        lastBottom = line.map((w) => w.bottom).reduce((a, b) => a > b ? a : b);
      }
      final values = cells.map((v) => v.join(' ').trim()).toList();
      if (values[0] != anchor.text ||
          values[1].isEmpty ||
          values[2].isEmpty ||
          values[3].isEmpty ||
          values[6].isEmpty) {
        // Deliberately use only fixed column labels and ordinal positions.
        // Never interpolate extracted words, receipt IDs, dates or amounts.
        final missing = [
          for (final c in [0, 1, 2, 3, 6])
            if (values[c].isEmpty) _columnNames[c],
        ];
        final conflicts = values[0] != anchor.text && values[0].isNotEmpty
            ? 'Receipt No.'
            : 'none';
        throw StatementImportException(
          'PDF layout diagnostic [ROW_CELLS]: page $pageNumber, row ${i + 1} on this page (table row ${_rows.length + 1}). Missing columns: ${missing.isEmpty ? 'none' : missing.join(', ')}. Conflicting columns: $conflicts. No partial import was saved. This diagnostic contains no transaction values.',
        );
      }
      _rows.add(values);
      if (_rows.length > 50000) {
        throw const StatementImportException(
          'Statement exceeds 50,000 rows. Import a shorter date range.',
        );
      }
    }
    // Date-bearing first-column text that was not a valid receipt must not be
    // silently ignored between otherwise valid rows.
    for (final line in _lines(body)) {
      final first = line.where((w) => column(w) == 0).toList();
      final date = line
          .where((w) => column(w) == 1)
          .map((w) => w.text)
          .join(' ');
      if (first.isNotEmpty &&
          RegExp(r'\d{2,4}[-/]\d{2}').hasMatch(date) &&
          !anchors.any((a) => first.contains(a))) {
        throw StatementImportException(
          'PDF layout diagnostic [RECEIPT]: page $pageNumber. Column: Receipt No.; an unreadable row marker was found. No partial import was saved. This diagnostic contains no transaction values.',
        );
      }
    }
  }

  static const _columnNames = [
    'Receipt No.',
    'Completion Time',
    'Details',
    'Transaction Status',
    'Paid In',
    'Withdrawn',
    'Balance',
  ];

  static final _footer = RegExp(
    r'^(?:Page\s*\d+(?:\s*of\s*\d+)?\b|Disclaimer\b|This\s+(?:is\s+a\s+(?:computer[ -]generated|system[ -]generated)|statement\b)|For\s+(?:further|assistance|enquiries|inquiries|queries|more information)\b|To verify\s+(?:this|the)\s+statement\b|End of statement\b|Please note\b|www\.)',
    caseSensitive: false,
  );

  String encode() =>
      '$marker$header\n${_rows.map((row) => row.map((v) => '"${v.replaceAll('"', '""')}"').join(',')).join('\n')}';
  static String _normal(String value) =>
      value.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  static List<List<StatementWord>> _lines(List<StatementWord> words) {
    final sorted = [...words]..sort((a, b) => a.top.compareTo(b.top));
    final lines = <List<StatementWord>>[];
    for (final word in sorted) {
      final height = lines.isEmpty
          ? word.height
          : lines.last
                .map((w) => w.height)
                .fold(word.height, (a, b) => a > b ? a : b);
      if (lines.isEmpty ||
          (word.top - lines.last.first.top).abs() > height * 0.8) {
        lines.add([word]);
      } else {
        lines.last.add(word);
      }
    }
    for (final line in lines) {
      line.sort((a, b) => a.left.compareTo(b.left));
    }
    return lines;
  }
}
