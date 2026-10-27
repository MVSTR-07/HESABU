/// PDF-independent positioned word, in top-left coordinates. No file access.
class StatementWord {
  const StatementWord(this.text, this.left, this.right, this.top, this.bottom);
  final String text;
  final double left, right, top, bottom;
  double get height => bottom - top;
}
