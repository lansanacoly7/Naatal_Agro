"""
Assemble les fichiers Markdown du mémoire (00-*.md à 03-*.md) en un document Word.

Usage :  python construire_docx.py
Résultat : ../Memoire_Naatal_Agro.docx

Conventions Markdown reconnues, en plus du texte courant :
  # Titre                      -> Titre 1 (saut de page pour les chapitres, la conclusion, la webographie, les annexes)
  ## / ###                     -> Titre 2 / Titre 3
  ![Légende](chemin){w=5}      -> figure numérotée, largeur 5 cm
  !![Légende](a|b|c){w=4.7}    -> une rangée de captures côte à côte, une seule légende
  Table: Légende               -> légende numérotée du tableau qui suit
  <!--LISTES-->                -> table des matières, liste des figures, liste des tableaux
  [À COMPLÉTER ...]            -> surligné en jaune (idem [À VÉRIFIER ...])

La numérotation des pages est en chiffres romains pour les pages liminaires, puis en chiffres arabes à partir de
l'introduction. Dans Word : clic droit sur une table, « Mettre à jour les champs », pour afficher les numéros de page.
"""
import re
import sys
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_COLOR_INDEX
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

HERE = Path(__file__).resolve().parent
RAPPORT = HERE.parent
OUTPUT = RAPPORT / 'Memoire_Naatal_Agro.docx'
PARTS = sorted(HERE.glob('0[0-9]-*.md'))
LOGO = HERE.parents[2] / 'mobile' / 'assets' / 'images' / 'naatal_agro_logo-removebg-preview.png'

GREEN = RGBColor(0x1B, 0x5E, 0x20)
TODO = re.compile(r'(\[(?:À COMPLÉTER|À VÉRIFIER)[^\]]*\])')
INLINE = re.compile(r'(\*\*[^*]+\*\*|\*[^*\s][^*]*\*|`[^`]+`)')
FONT = 'Times New Roman'
UNNUMBERED = ('Dédicace', 'Remerciements', 'Résumé', 'Abstract', 'Liste des sigles', 'Table des matières',
              'Liste des figures', 'Liste des tableaux')
BREAK_BEFORE = ('CHAPITRE', 'Conclusion', 'Webographie', 'Annexes', 'Introduction générale') + UNNUMBERED

counters = {'figure': 0, 'table': 0}


def set_font(run, name=FONT):
    run.font.name = name
    run._element.rPr.rFonts.set(qn('w:eastAsia'), name)


def add_runs(paragraph, text, size=None):
    for chunk in TODO.split(text):
        if not chunk:
            continue
        highlight = bool(TODO.fullmatch(chunk))
        for piece in INLINE.split(chunk):
            if not piece:
                continue
            if piece.startswith('**') and piece.endswith('**'):
                run = paragraph.add_run(piece[2:-2])
                run.bold = True
            elif piece.startswith('`') and piece.endswith('`'):
                run = paragraph.add_run(piece[1:-1])
                set_font(run, 'Consolas')
                run.font.size = Pt(10)
            elif piece.startswith('*') and piece.endswith('*') and len(piece) > 2:
                run = paragraph.add_run(piece[1:-1])
                run.italic = True
            else:
                run = paragraph.add_run(piece)
            if size and not (piece.startswith('`') and piece.endswith('`')):
                run.font.size = Pt(size)
            if highlight:
                run.font.highlight_color = WD_COLOR_INDEX.YELLOW


def field(paragraph, instruction, placeholder=''):
    """Insère un champ Word (numéro de page, séquence, table des matières...)."""
    run = paragraph.add_run()
    begin = OxmlElement('w:fldChar')
    begin.set(qn('w:fldCharType'), 'begin')
    instr = OxmlElement('w:instrText')
    instr.set(qn('xml:space'), 'preserve')
    instr.text = f' {instruction} '
    separate = OxmlElement('w:fldChar')
    separate.set(qn('w:fldCharType'), 'separate')
    text = OxmlElement('w:t')
    text.text = placeholder
    end = OxmlElement('w:fldChar')
    end.set(qn('w:fldCharType'), 'end')
    for element in (begin, instr, separate, text, end):
        run._r.append(element)
    return run


def shade(cell, color):
    properties = cell._tc.get_or_add_tcPr()
    shading = OxmlElement('w:shd')
    shading.set(qn('w:val'), 'clear')
    shading.set(qn('w:color'), 'auto')
    shading.set(qn('w:fill'), color)
    properties.append(shading)


def no_split(row):
    properties = row._tr.get_or_add_trPr()
    element = OxmlElement('w:cantSplit')
    properties.append(element)


def repeat_header(row):
    properties = row._tr.get_or_add_trPr()
    element = OxmlElement('w:tblHeader')
    properties.append(element)


def caption(document, kind, text, keep_next=False):
    label = 'Figure' if kind == 'figure' else 'Tableau'
    counters[kind] += 1
    paragraph = document.add_paragraph(style='Caption')
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.keep_with_next = keep_next
    run = paragraph.add_run(f'{label} ')
    run.bold = True
    field(paragraph, f'SEQ {label} \\* ARABIC', str(counters[kind])).bold = True
    run = paragraph.add_run(' : ')
    run.bold = True
    add_runs(paragraph, text)
    return paragraph


def add_table(document, rows, title):
    if title:
        caption(document, 'table', title, keep_next=True)
    header, body = rows[0], rows[1:]
    table = document.add_table(rows=1, cols=len(header))
    table.style = 'Table Grid'
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for index, text in enumerate(header):
        cell = table.rows[0].cells[index]
        cell.text = ''
        add_runs(cell.paragraphs[0], text, size=10)
        for run in cell.paragraphs[0].runs:
            run.bold = True
            run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        shade(cell, '1B5E20')
    repeat_header(table.rows[0])
    weights = [max(13, min(55, max(len(re.sub(r'[*`]', '', (r[i] if i < len(r) else ''))) for r in rows))) for i in range(len(header))]
    table.autofit = False
    total = sum(weights)
    widths = [Cm(15.5 * w / total) for w in weights]
    for number, row in enumerate(body):
        cells = table.add_row().cells
        no_split(table.rows[-1])
        for index in range(len(header)):
            cells[index].text = ''
            add_runs(cells[index].paragraphs[0], row[index] if index < len(row) else '', size=10)
            cells[index].paragraphs[0].paragraph_format.line_spacing = 1.0
            cells[index].paragraphs[0].paragraph_format.space_after = Pt(2)
            if number % 2:
                shade(cells[index], 'F1F6F1')
    for table_row in table.rows:
        for index, width in enumerate(widths):
            table_row.cells[index].width = width
    spacer = document.add_paragraph()
    spacer.paragraph_format.space_after = Pt(4)


def add_figure_row(document, title, paths, width_cm):
    row = document.add_paragraph()
    row.alignment = WD_ALIGN_PARAGRAPH.CENTER
    row.paragraph_format.keep_with_next = True
    row.paragraph_format.space_after = Pt(2)
    row.paragraph_format.line_spacing = 1.0
    for index, rel in enumerate(paths):
        path = (RAPPORT / 'memoire' / rel).resolve()
        if not path.exists():
            path = (RAPPORT / rel).resolve()
        if not path.exists():
            add_runs(row, f'[À COMPLÉTER : image manquante {rel}]')
            continue
        run = row.add_run()
        run.add_picture(str(path), width=Cm(width_cm))
        if index < len(paths) - 1:
            row.add_run('  ')
    caption(document, 'figure', title)


def cover_page(document):
    def centered(text, size, bold=False, space_after=12, color=None, italic=False):
        paragraph = document.add_paragraph()
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        paragraph.paragraph_format.space_after = Pt(space_after)
        paragraph.paragraph_format.line_spacing = 1.15
        add_runs(paragraph, text)
        for run in paragraph.runs:
            run.font.size = Pt(size)
            run.bold = bold
            run.italic = italic
            if color is not None and not run.font.highlight_color:
                run.font.color.rgb = color

    centered("Institut Supérieur d'Enseignement Professionnel (ISEP)", 15, True, 4, GREEN)
    centered('[À COMPLÉTER : site ou campus, filière, niveau]', 11, False, 30)
    centered('Mémoire de fin de formation', 13, False, 4, italic=True)
    centered('[À COMPLÉTER : diplôme préparé]', 11, False, 24)
    if LOGO.exists():
        paragraph = document.add_paragraph()
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        paragraph.add_run().add_picture(str(LOGO), width=Cm(5.2))
    centered('NAATAL AGRO', 30, True, 6, GREEN)
    centered("Application mobile d'aide à la décision pour les producteurs sénégalais, avec un assistant "
             'conversationnel aux réponses sourcées', 14, False, 40)
    centered('Présenté par : **Lassana Coly**', 12, False, 2)
    centered('[À COMPLÉTER : vérifier le nom, ajouter le ou les co-auteurs (par exemple Pathé Fall)]', 10, False, 18)
    centered('Encadrant pédagogique : [À COMPLÉTER : nom, titre]', 12, False, 2)
    centered('Encadrant professionnel : [À COMPLÉTER : nom, titre, structure, ou « sans objet »]', 12, False, 24)
    centered('Membres du jury : [À COMPLÉTER : noms et titres]', 12, False, 6)
    centered('Soutenu le [À COMPLÉTER : date]  ·  Année académique [À COMPLÉTER : 20XX-20XX]', 12, False, 6)


def toc_page(document, title, instruction, placeholder):
    document.add_page_break()
    document.add_paragraph(title, style='Heading 1')
    paragraph = document.add_paragraph()
    field(paragraph, instruction, placeholder)


def lists_pages(document):
    toc_page(document, 'Table des matières', 'TOC \\o "1-3" \\h \\z \\u',
             'Table des matières : dans Word, clic droit puis « Mettre à jour les champs ».')
    toc_page(document, 'Liste des figures', 'TOC \\h \\z \\c "Figure"', 'Liste des figures : mettre à jour les champs.')
    toc_page(document, 'Liste des tableaux', 'TOC \\h \\z \\c "Tableau"', 'Liste des tableaux : mettre à jour les champs.')


def new_section(document, roman):
    section = document.add_section(WD_SECTION.NEW_PAGE)
    set_page_numbers(section, roman, restart=True)
    return section


def set_page_numbers(section, roman, restart=False):
    properties = section._sectPr
    for old in properties.findall(qn('w:pgNumType')):
        properties.remove(old)
    number = OxmlElement('w:pgNumType')
    number.set(qn('w:fmt'), 'lowerRoman' if roman else 'decimal')
    if restart:
        number.set(qn('w:start'), '1')
    properties.append(number)
    section.footer.is_linked_to_previous = False
    footer = section.footer.paragraphs[0]
    for run in list(footer.runs):
        run._r.getparent().remove(run._r)
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    field(footer, 'PAGE', '1')
    for run in footer.runs:
        run.font.size = Pt(10)


def convert(document, markdown, state):
    table_rows = []
    table_title = None

    def flush_table():
        nonlocal table_rows, table_title
        if table_rows:
            add_table(document, table_rows, table_title)
            table_rows, table_title = [], None

    lines = markdown.splitlines()
    for raw in lines:
        line = raw.rstrip()
        if line.startswith('|'):
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if all(re.fullmatch(r':?-{2,}:?', c) for c in cells):
                continue
            table_rows.append(cells)
            continue
        flush_table()
        stripped = line.strip()
        if not stripped or stripped == '---':
            continue
        if stripped == '<!--LISTES-->':
            lists_pages(document)
            state['after_lists'] = True
            continue
        title = re.match(r'^Table:\s*(.*)$', stripped)
        if title:
            table_title = title.group(1)
            continue
        row = re.match(r'^!!\[(.*?)\]\((.*?)\)(?:\{w=([\d.]+)\})?$', stripped)
        if row:
            add_figure_row(document, row.group(1), row.group(2).split('|'), float(row.group(3) or 4.9))
            continue
        figure = re.match(r'^!\[(.*?)\]\((.*?)\)(?:\{w=([\d.]+)\})?$', stripped)
        if figure:
            add_figure_row(document, figure.group(1), [figure.group(2)], float(figure.group(3) or 14))
            continue
        heading = re.match(r'^(#{1,3})\s+(.*)$', stripped)
        if heading:
            level, text = len(heading.group(1)), heading.group(2)
            if level == 1 and text.startswith('Introduction générale') and state['liminaires']:
                state['liminaires'] = False
                new_section(document, roman=False)
                state['fresh'] = True
            elif level == 1 and text.startswith(BREAK_BEFORE) and not state['fresh']:
                document.add_page_break()
            state['fresh'] = False
            document.add_paragraph(text, style=f'Heading {level}')
            continue
        quote = re.match(r'^>\s*(.*)$', stripped)
        if quote:
            paragraph = document.add_paragraph()
            paragraph.paragraph_format.left_indent = Cm(1)
            paragraph.paragraph_format.right_indent = Cm(1)
            add_runs(paragraph, quote.group(1))
            for run in paragraph.runs:
                run.italic = True
            continue
        bullet = re.match(r'^[-*]\s+(.*)$', stripped)
        if bullet:
            paragraph = document.add_paragraph(style='List Bullet')
            paragraph.paragraph_format.space_after = Pt(3)
            add_runs(paragraph, bullet.group(1))
            continue
        numbered = re.match(r'^(\d+)\.\s+(.*)$', stripped)
        if numbered:
            paragraph = document.add_paragraph()
            paragraph.paragraph_format.left_indent = Cm(1.0)
            paragraph.paragraph_format.first_line_indent = Cm(-0.6)
            paragraph.paragraph_format.space_after = Pt(3)
            add_runs(paragraph, f'{numbered.group(1)}.  {numbered.group(2)}')
            continue
        paragraph = document.add_paragraph()
        paragraph.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        if re.fullmatch(r'\*\*[^*]+\*\*|\*[^*]+\*', stripped) or re.fullmatch(r'\*\*[^*]+\*\*\s*\*?\(?[^*]*\)?\*?', stripped) and len(stripped) < 90:
            paragraph.paragraph_format.keep_with_next = True
            paragraph.paragraph_format.first_line_indent = Cm(0)
        else:
            paragraph.paragraph_format.first_line_indent = Cm(0.8)
        add_runs(paragraph, stripped)
    flush_table()


def style_document(document):
    section = document.sections[0]
    section.page_height, section.page_width = Cm(29.7), Cm(21.0)
    section.left_margin, section.right_margin = Cm(3.0), Cm(2.5)
    section.top_margin = section.bottom_margin = Cm(2.5)
    normal = document.styles['Normal']
    normal.font.name = FONT
    normal.font.size = Pt(12)
    normal.element.rPr.rFonts.set(qn('w:eastAsia'), FONT)
    normal.paragraph_format.line_spacing = 1.5
    normal.paragraph_format.space_after = Pt(6)
    for name, size, before, after in (('Heading 1', 18, 0, 18), ('Heading 2', 15, 18, 8), ('Heading 3', 13, 12, 6)):
        style = document.styles[name]
        style.font.name = FONT
        fonts = style.element.rPr.rFonts
        fonts.set(qn('w:eastAsia'), FONT)
        for attribute in ('w:asciiTheme', 'w:hAnsiTheme', 'w:eastAsiaTheme', 'w:cstheme'):
            if fonts.get(qn(attribute)) is not None:
                del fonts.attrib[qn(attribute)]
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = GREEN
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True
        style.paragraph_format.line_spacing = 1.15
    caption_style = document.styles['Caption']
    caption_style.font.name = FONT
    caption_style.font.size = Pt(10)
    caption_style.font.italic = False
    caption_style.font.bold = False
    caption_style.font.color.rgb = RGBColor(0x33, 0x33, 0x33)
    caption_style.paragraph_format.space_after = Pt(12)
    caption_style.paragraph_format.line_spacing = 1.0
    for name in ('TOC 1', 'TOC 2', 'TOC 3', 'Table of Figures'):
        if name in [s.name for s in document.styles]:
            document.styles[name].font.name = FONT
    # Word propose de mettre à jour les champs (numéros de page, tables) à l'ouverture
    settings = document.settings.element
    update = OxmlElement('w:updateFields')
    update.set(qn('w:val'), 'true')
    settings.append(update)


def main():
    document = Document()
    style_document(document)
    cover_page(document)
    new_section(document, roman=True)
    state = {'liminaires': True, 'after_lists': False, 'fresh': True}
    # La page de garde n'est pas numérotée : on retire le pied de page de la première section
    for part in PARTS:
        convert(document, part.read_text(encoding='utf-8'), state)
    document.core_properties.title = 'Naatal Agro : application mobile d\'aide à la décision pour les producteurs sénégalais'
    document.core_properties.author = 'Lassana Coly'
    document.core_properties.language = 'fr-FR'
    document.save(OUTPUT)
    words = sum(len(part.read_text(encoding='utf-8').split()) for part in PARTS)
    print(f'{OUTPUT.name} généré ({words} mots, {counters["figure"]} figures, {counters["table"]} tableaux).')


if __name__ == '__main__':
    sys.exit(main())
