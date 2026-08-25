from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.units import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_CENTER, TA_LEFT

def create_pdf():
    doc = SimpleDocTemplate("Treepnet_English.pdf", pagesize=A4,
                            rightMargin=50, leftMargin=50,
                            topMargin=50, bottomMargin=50)
    styles = getSampleStyleSheet()
    
    style_center = ParagraphStyle(name='Center', parent=styles['Normal'], alignment=TA_CENTER, spaceAfter=14)
    style_title = ParagraphStyle(name='Title', parent=styles['Title'], alignment=TA_CENTER, spaceAfter=10, fontSize=16)
    style_label = ParagraphStyle(name='Label', parent=styles['Normal'], alignment=TA_CENTER, spaceAfter=4, fontSize=9)
    style_value = ParagraphStyle(name='Value', parent=styles['Normal'], alignment=TA_CENTER, spaceAfter=14, fontSize=12, fontName="Helvetica-Bold")
    style_left_label = ParagraphStyle(name='LeftLabel', parent=styles['Normal'], alignment=TA_LEFT, spaceAfter=4, fontSize=9)
    style_left_value = ParagraphStyle(name='LeftValue', parent=styles['Normal'], alignment=TA_LEFT, spaceAfter=14, fontSize=12, fontName="Helvetica-Bold")
    
    Story = []
    
    Story.append(Paragraph("CERTIFICATE", style_title))
    Story.append(Paragraph("on state registration of a legal entity", style_center))
    Story.append(Spacer(1, 0.2 * inch))
    
    Story.append(Paragraph("Legal entity", style_label))
    Story.append(Paragraph('"TREEP NET" LIMITED LIABILITY COMPANY', style_value))
    
    Story.append(Paragraph("Full name of the legal entity - business entity indicating the organizational and legal form", style_label))
    Story.append(Spacer(1, 0.1 * inch))
    
    Story.append(Paragraph('"TREEP NET" LLC', style_value))
    Story.append(Paragraph("Abbreviated name of the legal entity", style_label))
    Story.append(Spacer(1, 0.1 * inch))
    
    Story.append(Paragraph("311 108 388", style_value))
    Story.append(Paragraph("Taxpayer Identification Number (TIN)", style_label))
    Story.append(Spacer(1, 0.2 * inch))
    
    Story.append(Paragraph("Establishment (reorganization, other registration, information alteration)", style_center))
    Story.append(Spacer(1, 0.2 * inch))
    
    Story.append(Paragraph("Date: 15.02.2024", style_left_value))
    Story.append(Paragraph("Approved: 2386988", style_left_value))
    Story.append(Spacer(1, 0.2 * inch))
    
    Story.append(Paragraph("Organizational-legal form:", style_left_label))
    Story.append(Paragraph("LIMITED LIABILITY COMPANY", style_left_value))
    
    Story.append(Paragraph("Address of the place of business operation:", style_left_label))
    Story.append(Paragraph("KHOREZM REGION, KHANKA DISTRICT, MADIR, DO'STLIK MCA, YOG'DU 1ST NARROW STREET, HOUSE 16AA", style_left_value))
    
    Story.append(Paragraph("Issued by:", style_left_label))
    Story.append(Paragraph("PUBLIC SERVICE CENTER OF KHANKA DISTRICT, KHOREZM REGION", style_left_value))
    
    Story.append(Paragraph("1816035", style_left_value))
    
    doc.build(Story)

if __name__ == '__main__':
    create_pdf()
