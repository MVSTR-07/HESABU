"""Fabricated portrait PDF layout regression; never reads a real statement."""
import base64
import textwrap
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.pdfencrypt import StandardEncryption
import pypdfium2 as pdfium

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'sample_output'
PASSWORD = 'demo-only-2026'

def main():
    import csv
    rows = list(csv.DictReader((OUT / 'fabricated_mpesa.csv').open(encoding='utf-8')))
    target = OUT / 'fabricated_mpesa_column_layout.pdf'
    pdf = canvas.Canvas(str(target), pagesize=A4, invariant=1,
        encrypt=StandardEncryption(PASSWORD, ownerPassword=PASSWORD+'-owner', strength=128))
    pdf.setTitle('Fabricated column-layout regression - no real business data')
    for page, chunk in enumerate([rows[:12], rows[12:]], 1):
        pdf.setFont('Helvetica-Bold', 12)
        pdf.drawString(30, 790, 'M-PESA STATEMENT - FABRICATED')
        pdf.setFont('Helvetica', 8)
        pdf.drawString(30, 773, 'Invented data only. Password: demo-only-2026')
        pdf.drawString(30, 750, 'SUMMARY: Transaction Type / Paid In / Paid Out')
        pdf.drawString(30, 735, 'Customer payments (fabricated summary, not a transaction row)')
        # A separate three-column summary, seven-column detail grid, and
        # two-column footer reproduce table STRUCTURE using invented data only.
        pdf.setStrokeColorRGB(.2, .65, .2)
        pdf.rect(28, 728, 557, 38, stroke=1, fill=0)
        for x in [328, 465]: pdf.line(x,728,x,766)
        grid_x = [28,98,188,328,395,465,525,585]
        bottom = 671-len(chunk)*40
        for x in grid_x: pdf.line(x,bottom,x,698)
        for yline in [698,671]+[671-i*40 for i in range(1,len(chunk)+1)]:
            pdf.line(28,yline,585,yline)
        pdf.setFont('Helvetica-Bold', 7)
        for x, line1, line2 in [(30,'Receipt','No.'),(100,'Completion','Time'),(190,'Details',''),
                (330,'Transaction','Status'),(415,'Paid In',''),(472,'Withdrawn',''),(535,'Balance','')]:
            pdf.drawString(x, 690, line1)
            if line2: pdf.drawString(x, 681, line2)
        pdf.setFont('Helvetica', 7)
        for index, row in enumerate(chunk):
            y = 660 - index * 40
            pdf.drawString(30, y, row['Receipt No.'])
            date, time = row['Completion Time'].split(' ')
            pdf.drawString(100, y, date)
            pdf.drawString(100, y-9, time)
            for offset, line in enumerate(textwrap.wrap(row['Details'], width=34)):
                pdf.drawString(190, y-offset*9, line)
            pdf.drawString(330, y, 'Completed')
            # Blank cells are intentional: flattening loses their direction.
            for key, right in [('Paid In',460),('Withdrawn',520),('Balance',580)]:
                amount = float(row[key])
                if amount or key == 'Balance': pdf.drawRightString(right, y, f'{amount:,.2f}')
        pdf.rect(28,45,557,45,stroke=1,fill=0)
        pdf.line(300,45,300,90)
        pdf.drawString(30,75,'Fabricated footer')
        pdf.drawString(305,75,'Not a transaction')
        pdf.drawString(30, 30, f'Page {page} of 2')
        pdf.showPage()
    pdf.save()
    data = base64.b64encode(target.read_bytes()).decode('ascii')
    source = ['// Fabricated two-page column-layout regression. No real business data.',
              'const sampleMpesaColumnPdfBase64 =']
    source.extend("    '" + data[i:i+100] + "'" for i in range(0,len(data),100))
    source[-1] += ';'
    (ROOT/'lib/core/mpesa/sample_column_pdf_bytes.dart').write_text('\n'.join(source)+'\n', encoding='utf-8')
    doc = pdfium.PdfDocument(str(target), password=PASSWORD)
    for index in range(len(doc)):
        bitmap = doc[index].render(scale=1.4)
        bitmap.to_pil().save(OUT/f'fabricated_column_preview_{index+1}.png')
        bitmap.close()
    doc.close()
    print('Created 2-page fabricated column-layout PDF and regression source.')

if __name__ == '__main__': main()
