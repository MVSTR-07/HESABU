import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as native;
import 'package:pdfrx_engine/pdfrx_engine.dart';

import '../core/mpesa/ruled_statement_table.dart';
import '../core/mpesa/pdf_layout_geometry.dart';

List<StatementWord> positionedPdfWords(PdfPageRawText text) {
  final words = <StatementWord>[];
  for (final match in RegExp(r'\S+').allMatches(text.fullText)) {
    PdfRect? bounds;
    for (var i = match.start; i < match.end && i < text.charRects.length; i++) {
      final rect = text.charRects[i];
      if (rect.isNotEmpty) bounds = bounds == null ? rect : bounds.merge(rect);
    }
    if (bounds != null) {
      words.add(
        StatementWord(
          match.group(0)!,
          bounds.left,
          bounds.right,
          -bounds.top,
          -bounds.bottom,
        ),
      );
    }
  }
  return words;
}

/// Read vector rulings through PDFium's public native-document API. The engine
/// suspends its worker while this callback owns the handle. Nothing is rendered,
/// exported or written. Form transforms are applied before returning geometry.
Future<List<StatementRule>> readStatementRules(
  PdfDocument document,
  int pageNumber,
) => document.useNativeDocumentHandle((handle) {
  final api = native.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
  final page = api.FPDF_LoadPage(
    native.FPDF_DOCUMENT.fromAddress(handle),
    pageNumber - 1,
  );
  if (page.address == 0) return <StatementRule>[];
  try {
    return using((arena) {
      final result = <StatementRule>[];
      var objects = 0;
      final x = arena<Float>(), y = arena<Float>();
      List<double> matrix(native.FPDF_PAGEOBJECT object) {
        final p = arena<native.FS_MATRIX>();
        if (api.FPDFPageObj_GetMatrix(object, p) == 0) {
          return [1, 0, 0, 1, 0, 0];
        }
        return [p.ref.a, p.ref.b, p.ref.c, p.ref.d, p.ref.e, p.ref.f];
      }

      List<double> multiply(List<double> p, List<double> m) => [
        p[0] * m[0] + p[2] * m[1],
        p[1] * m[0] + p[3] * m[1],
        p[0] * m[2] + p[2] * m[3],
        p[1] * m[2] + p[3] * m[3],
        p[0] * m[4] + p[2] * m[5] + p[4],
        p[1] * m[4] + p[3] * m[5] + p[5],
      ];
      void visit(
        native.FPDF_PAGEOBJECT object,
        List<double> parent,
        int depth,
      ) {
        if (object.address == 0) return;
        if (depth > 16 || ++objects > 200000) {
          throw StateError('PDF vector complexity limit exceeded.');
        }
        final type = api.FPDFPageObj_GetType(object);
        if (type != native.FPDF_PAGEOBJ_FORM &&
            type != native.FPDF_PAGEOBJ_PATH) {
          return;
        }
        final transform = multiply(parent, matrix(object));
        if (type == native.FPDF_PAGEOBJ_FORM) {
          final count = api.FPDFFormObj_CountObjects(object);
          for (var i = 0; i < count; i++) {
            visit(api.FPDFFormObj_GetObject(object, i), transform, depth + 1);
          }
          return;
        }
        if (type != native.FPDF_PAGEOBJ_PATH) return;
        (double, double)? previous, first;
        void line((double, double) a, (double, double) b) {
          if ((a.$1 - b.$1).abs() < .1 || (a.$2 - b.$2).abs() < .1) {
            result.add(StatementRule(a.$1, -a.$2, b.$1, -b.$2));
          }
        }

        final count = api.FPDFPath_CountSegments(object);
        if (count > 100000) {
          throw StateError('PDF path complexity limit exceeded.');
        }
        for (var i = 0; i < count; i++) {
          final segment = api.FPDFPath_GetPathSegment(object, i);
          if (segment.address == 0 ||
              api.FPDFPathSegment_GetPoint(segment, x, y) == 0) {
            continue;
          }
          final point = (
            transform[0] * x.value + transform[2] * y.value + transform[4],
            transform[1] * x.value + transform[3] * y.value + transform[5],
          );
          final kind = api.FPDFPathSegment_GetType(segment);
          if (kind == native.FPDF_SEGMENT_MOVETO) {
            first = point;
            previous = point;
          } else if (kind == native.FPDF_SEGMENT_LINETO) {
            if (previous != null) line(previous, point);
            previous = point;
          } else {
            previous = null;
          }
          if (api.FPDFPathSegment_GetClose(segment) != 0 &&
              first != null &&
              previous != null) {
            line(previous, first);
            previous = first;
          }
        }
      }

      final count = api.FPDFPage_CountObjects(page);
      for (var i = 0; i < count; i++) {
        visit(api.FPDFPage_GetObject(page, i), [1, 0, 0, 1, 0, 0], 0);
      }
      return result;
    });
  } finally {
    api.FPDF_ClosePage(page);
  }
});
