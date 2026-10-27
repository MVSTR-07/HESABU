"""Rebuild ONLY fabricated samples, never accept actual statements.

First run tool/export_mpesa_sample.dart --pdf-source. Requires reportlab, pypdf, pypdfium2.
Generated PDF/CSV/JSON/PNG outputs are ignored by Git; only encoded, fabricated
PDF bytes are embedded in Dart so users need no Python at runtime.
"""
import base64
import json
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A3, landscape
from reportlab.lib.pdfencrypt import StandardEncryption
from pypdf import PdfReader
import pypdfium2 as pdfium

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'sample_output'
PASSWORD = 'demo-only-2026'  # Public, fabricated fixture only.


def main():
    rows = json.loads((OUT / 'fabricated_rows.json').read_text(encoding='utf-8'))
    target = OUT / 'fabricated_mpesa_protected.pdf'
    width, height = landscape(A3)
    encryption = StandardEncryption(PASSWORD, ownerPassword=PASSWORD + '-owner',
                                    strength=128, canPrint=1, canCopy=1)
    pdf = canvas.Canvas(str(target), pagesize=(width, height), encrypt=encryption,
                        invariant=1)
    pdf.setTitle('Fabricated M-Pesa statement - no real business data')
    pdf.setFont('Helvetica-Bold', 16)
    pdf.drawString(28, height - 36, 'M-PESA STATEMENT - FABRICATED TEST DATA')
    pdf.setFont('Helvetica', 10)
    pdf.drawString(28, height - 56, 'Statement period: 01/01/2026 to 10/01/2026. Opening balance: KES 20,000.00')
    pdf.drawString(28, height - 73, 'This is a fabricated test fixture. Every name, receipt and phone number is invented.')
    xs = [28, 120, 265, 735, 815, 925, 1035]
    widths = [92, 145, 470, 80, 110, 110, 125]
    headers = ['Receipt No.', 'Completion Time', 'Details', 'Status', 'Paid In', 'Withdrawn', 'Balance']
    y = height - 108
    pdf.setFont('Helvetica-Bold', 9)
    for x, text in zip(xs, headers):
        pdf.drawString(x, y, text)
    pdf.line(28, y - 7, width - 28, y - 7)
    pdf.setFont('Helvetica', 9)
    for row in rows:
        y -= 23
        values = [row['receipt'], row['localDate'], row['details'], 'Completed',
                  f"{row['in'] / 100:,.2f}", f"{row['out'] / 100:,.2f}",
                  f"{row['balance'] / 100:,.2f}"]
        for x, cell_width, text in zip(xs, widths, values):
            assert pdf.stringWidth(text, 'Helvetica', 9) < cell_width - 5
            pdf.drawString(x, y, text)
    pdf.setFont('Helvetica', 9)
    pdf.drawString(28, 28, 'Page 1 of 1')
    pdf.save()
    reader = PdfReader(target)
    assert reader.is_encrypted and reader.decrypt(PASSWORD)
    assert len(reader.pages) == 1
    assert 'QA26A00018' in reader.pages[0].extract_text()
    # Render the encrypted final PDF with the real password for visual QA.
    document = pdfium.PdfDocument(str(target), password=PASSWORD)
    bitmap = document[0].render(scale=1.25)
    bitmap.to_pil().save(OUT / 'fabricated_mpesa_preview.png')
    bitmap.close()
    document.close()
    data = base64.b64encode(target.read_bytes()).decode('ascii')
    lines = ['// Generated from fabricated samples by tool/generate_mpesa_fixtures.py.',
             '// No real statements or user passwords belong in this file.',
             'const sampleMpesaEncryptedPdfBase64 =']
    lines.extend("    '" + data[i:i+100] + "'" for i in range(0, len(data), 100))
    lines[-1] += ';'
    (ROOT / 'lib/core/mpesa/sample_pdf_bytes.dart').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'Generated fabricated encrypted PDF ({len(rows)} rows), source bytes and preview.')


if __name__ == '__main__':
    main()
