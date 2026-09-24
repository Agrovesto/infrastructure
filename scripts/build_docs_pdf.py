#!/usr/bin/env python3
# Rebuild docs/TECHNICAL-DOCUMENTATION.pdf from the .md (pip install markdown xhtml2pdf; needs DejaVu fonts).
import markdown, re
from xhtml2pdf import pisa
from xhtml2pdf.default import DEFAULT_FONT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.fonts import addMapping
D='/usr/share/fonts/truetype/dejavu/'
for n,f in [('dv','DejaVuSans.ttf'),('dvb','DejaVuSans-Bold.ttf'),('dvm','DejaVuSansMono.ttf'),('dvmb','DejaVuSansMono-Bold.ttf')]:
    pdfmetrics.registerFont(TTFont(n,D+f))
addMapping('dv',0,0,'dv');addMapping('dv',1,0,'dvb');addMapping('dv',0,1,'dv');addMapping('dv',1,1,'dvb')
addMapping('dvm',0,0,'dvm');addMapping('dvm',1,0,'dvmb');addMapping('dvm',0,1,'dvm');addMapping('dvm',1,1,'dvmb')
DEFAULT_FONT.update({'dv':'dv','dvm':'dvm'})
src=open('docs/TECHNICAL-DOCUMENTATION.md').read()
html=markdown.markdown(src, extensions=['tables','fenced_code'])
css='''
@page { size: A4; margin: 1.6cm 1.5cm 1.8cm 1.5cm;
  @frame footer { -pdf-frame-content: foot; bottom: 0.7cm; margin-left: 1.5cm; margin-right: 1.5cm; height: 0.6cm; } }
body { font-family: dv; font-size: 9pt; color: #1f2937; line-height: 1.35; }
h1 { font-size: 19pt; color: #14532d; border-bottom: 2px solid #16a34a; padding-bottom: 4px; }
h2 { font-size: 13.5pt; color: #14532d; margin-top: 16px; border-bottom: 1px solid #bbf7d0; padding-bottom: 2px; -pdf-keep-with-next: true; }
h3 { font-size: 11pt; color: #166534; margin-top: 10px; -pdf-keep-with-next: true; }
table { border: 0.5px solid #9ca3af; margin: 5px 0 8px 0; }
th { background-color: #dcfce7; color: #14532d; font-weight: bold; padding: 3px 4px; border: 0.5px solid #9ca3af; font-size: 8pt; text-align: left; }
td { padding: 3px 4px; border: 0.5px solid #d1d5db; font-size: 8pt; vertical-align: top; }
code { font-family: dvm; font-size: 7.8pt; color: #7c2d12; }
pre { font-family: dvm; font-size: 7.5pt; background-color: #f3f4f6; border: 0.5px solid #d1d5db; padding: 6px; }
blockquote { background-color: #f0fdf4; border-left: 3px solid #16a34a; padding: 4px 8px; color: #374151; }
hr { color: #d1d5db; }
'''
doc=f'<html><head><meta charset="utf-8"><style>{css}</style></head><body>{html}<div id="foot" style="text-align:center;font-size:7.5pt;color:#6b7280">Agrovesto Infrastructure: Technical Documentation · page <pdf:pagenumber/> of <pdf:pagecount/></div></body></html>'
with open('docs/TECHNICAL-DOCUMENTATION.pdf','wb') as f:
    r=pisa.CreatePDF(doc, dest=f, encoding='utf-8')
print('errors', r.err)
