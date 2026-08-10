from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(r"D:\Projetos Pessoais\grupo_alessat_app")
OUTPUT = ROOT / "documentacao" / "Documentacao_Tecnica_Grupo_Alessat_App_2.0.1.docx"
TMP = ROOT / "tmp" / "docs_intelbras"
LOGO = ROOT / "assets" / "logo-login-alessat-dark.png"
FLOW = TMP / "fluxo_mosaico.png"

NAVY = "153746"
BLUE = "0794BC"
LIGHT_BLUE = "E8F4F8"
LIGHT_GRAY = "F2F4F7"
MID_GRAY = "667085"
DARK = "1E262D"
WHITE = "FFFFFF"
GREEN = "157A55"
AMBER = "A15C00"
BORDER = "D0D5DD"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=100, start=120, bottom=100, end=120):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for margin, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{margin}"))
        if node is None:
            node = OxmlElement(f"w:{margin}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def set_table_geometry(table, widths_dxa, indent_dxa=120):
    total = sum(widths_dxa)
    table.autofit = False
    tbl_pr = table._tbl.tblPr
    tbl_w = tbl_pr.find(qn("w:tblW"))
    if tbl_w is None:
        tbl_w = OxmlElement("w:tblW")
        tbl_pr.append(tbl_w)
    tbl_w.set(qn("w:w"), str(total))
    tbl_w.set(qn("w:type"), "dxa")
    tbl_ind = tbl_pr.find(qn("w:tblInd"))
    if tbl_ind is None:
        tbl_ind = OxmlElement("w:tblInd")
        tbl_pr.append(tbl_ind)
    tbl_ind.set(qn("w:w"), str(indent_dxa))
    tbl_ind.set(qn("w:type"), "dxa")

    grid = table._tbl.tblGrid
    for child in list(grid):
        grid.remove(child)
    for width in widths_dxa:
        grid_col = OxmlElement("w:gridCol")
        grid_col.set(qn("w:w"), str(width))
        grid.append(grid_col)

    for row in table.rows:
        for idx, cell in enumerate(row.cells):
            width = widths_dxa[min(idx, len(widths_dxa) - 1)]
            tc_pr = cell._tc.get_or_add_tcPr()
            tc_w = tc_pr.find(qn("w:tcW"))
            if tc_w is None:
                tc_w = OxmlElement("w:tcW")
                tc_pr.append(tc_w)
            tc_w.set(qn("w:w"), str(width))
            tc_w.set(qn("w:type"), "dxa")
            set_cell_margins(cell)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def set_table_borders(table, color=BORDER, size=6):
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.find(qn("w:tblBorders"))
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tbl_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        element = borders.find(qn(f"w:{edge}"))
        if element is None:
            element = OxmlElement(f"w:{edge}")
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), str(size))
        element.set(qn("w:color"), color)


def set_run_font(run, name="Calibri", size=None, color=None, bold=None, italic=None):
    run.font.name = name
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), name)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), name)
    if size is not None:
        run.font.size = Pt(size)
    if color is not None:
        run.font.color.rgb = RGBColor.from_string(color)
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic


def add_field(paragraph, field_code):
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instruction = OxmlElement("w:instrText")
    instruction.set(qn("xml:space"), "preserve")
    instruction.text = field_code
    separate = OxmlElement("w:fldChar")
    separate.set(qn("w:fldCharType"), "separate")
    text = OxmlElement("w:t")
    text.text = "1"
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    for element in (begin, instruction, separate, text, end):
        run._r.append(element)
    set_run_font(run, size=9, color=MID_GRAY)


def configure_styles(doc):
    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal._element.rPr.rFonts.set(qn("w:ascii"), "Calibri")
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Calibri")
    normal.font.size = Pt(11)
    normal.paragraph_format.space_before = Pt(0)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.10

    for name, size, color, before, after in (
        ("Heading 1", 16, BLUE, 16, 8),
        ("Heading 2", 13, BLUE, 12, 6),
        ("Heading 3", 12, NAVY, 8, 4),
    ):
        style = doc.styles[name]
        style.font.name = "Calibri"
        style._element.rPr.rFonts.set(qn("w:ascii"), "Calibri")
        style._element.rPr.rFonts.set(qn("w:hAnsi"), "Calibri")
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = RGBColor.from_string(color)
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True

    for name in ("List Bullet", "List Number"):
        style = doc.styles[name]
        style.font.name = "Calibri"
        style.font.size = Pt(11)
        style.paragraph_format.left_indent = Inches(0.5)
        style.paragraph_format.first_line_indent = Inches(-0.25)
        style.paragraph_format.space_after = Pt(8)
        style.paragraph_format.line_spacing = 1.167


def configure_page(section):
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(0.78)
    section.bottom_margin = Inches(0.75)
    section.left_margin = Inches(0.85)
    section.right_margin = Inches(0.85)
    section.header_distance = Inches(0.38)
    section.footer_distance = Inches(0.38)


def configure_header_footer(section):
    header = section.header
    table = header.add_table(rows=1, cols=2, width=Inches(6.8))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_geometry(table, [5200, 4592], indent_dxa=0)
    left, right = table.rows[0].cells
    p = left.paragraphs[0]
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run("GRUPO ALESSAT APP")
    set_run_font(r, size=8.5, color=NAVY, bold=True)
    p = right.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run("DOCUMENTAÇÃO TÉCNICA | INTELBRAS")
    set_run_font(r, size=8.5, color=MID_GRAY)

    footer = section.footer
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(3)
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run("Versão 2.0.1  |  07/08/2026  |  Página ")
    set_run_font(r, size=9, color=MID_GRAY)
    add_field(p, "PAGE")


def add_heading(doc, text, level=1):
    p = doc.add_paragraph(text, style=f"Heading {level}")
    p.paragraph_format.keep_with_next = True
    return p


def add_body(doc, text, bold_prefix=None):
    p = doc.add_paragraph()
    if bold_prefix and text.startswith(bold_prefix):
        r = p.add_run(bold_prefix)
        set_run_font(r, bold=True, color=NAVY)
        r = p.add_run(text[len(bold_prefix):])
        set_run_font(r)
    else:
        r = p.add_run(text)
        set_run_font(r)
    return p


def add_bullet(doc, text):
    p = doc.add_paragraph(style="List Bullet")
    r = p.add_run(text)
    set_run_font(r)
    return p


def add_number(doc, text):
    p = doc.add_paragraph(style="List Number")
    r = p.add_run(text)
    set_run_font(r)
    return p


def add_callout(doc, label, text, fill=LIGHT_BLUE, accent=BLUE):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_geometry(table, [9360], indent_dxa=120)
    set_table_borders(table, color=accent, size=8)
    cell = table.cell(0, 0)
    set_cell_shading(cell, fill)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run(f"{label}: ")
    set_run_font(r, bold=True, color=NAVY)
    r = p.add_run(text)
    set_run_font(r, color=DARK)
    doc.add_paragraph().paragraph_format.space_after = Pt(0)
    return table


def add_table(doc, headers, rows, widths_dxa):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_geometry(table, widths_dxa, indent_dxa=120)
    set_table_borders(table)
    hdr = table.rows[0]
    set_repeat_table_header(hdr)
    for idx, text in enumerate(headers):
        cell = hdr.cells[idx]
        set_cell_shading(cell, LIGHT_GRAY)
        p = cell.paragraphs[0]
        p.paragraph_format.space_after = Pt(0)
        r = p.add_run(text)
        set_run_font(r, size=9.5, color=NAVY, bold=True)
    for row_values in rows:
        cells = table.add_row().cells
        for idx, value in enumerate(row_values):
            p = cells[idx].paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            r = p.add_run(str(value))
            set_run_font(r, size=9.2, color=DARK)
    set_table_geometry(table, widths_dxa, indent_dxa=120)
    return table


def build_flow_diagram():
    width, height = 1800, 480
    img = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(img)
    try:
        title_font = ImageFont.truetype("arialbd.ttf", 34)
        body_font = ImageFont.truetype("arial.ttf", 26)
        small_font = ImageFont.truetype("arial.ttf", 22)
    except OSError:
        title_font = body_font = small_font = ImageFont.load_default()

    boxes = [
        (30, 120, 330, 360, "1", "Aplicativo", "Seleção do mosaico"),
        (390, 120, 690, 360, "2", "API Moovsec", "Prepara live media\nporta 3000"),
        (750, 120, 1050, 360, "3", "Resposta", "Thumbnail temporário\nou URL .m3u8"),
        (1110, 120, 1410, 360, "4", "Servidor HLS", "Playlist e segmentos\nporta 3010"),
        (1470, 120, 1770, 360, "5", "Player", "Exibição na célula\ndo mosaico"),
    ]
    draw.text((30, 35), "Fluxo de abertura de uma câmera no mosaico", font=title_font, fill=(21, 55, 70))
    for i, (x1, y1, x2, y2, num, title, detail) in enumerate(boxes):
        fill = (232, 244, 248) if i % 2 == 0 else (242, 244, 247)
        draw.rounded_rectangle((x1, y1, x2, y2), radius=20, fill=fill, outline=(7, 148, 188), width=4)
        draw.ellipse((x1 + 18, y1 + 18, x1 + 72, y1 + 72), fill=(7, 148, 188))
        bbox = draw.textbbox((0, 0), num, font=body_font)
        draw.text((x1 + 45 - (bbox[2] - bbox[0]) / 2, y1 + 45 - (bbox[3] - bbox[1]) / 2 - 2), num, font=body_font, fill="white")
        draw.text((x1 + 28, y1 + 90), title, font=body_font, fill=(21, 55, 70))
        y = y1 + 145
        for line in detail.split("\n"):
            draw.text((x1 + 28, y), line, font=small_font, fill=(75, 85, 99))
            y += 34
        if i < len(boxes) - 1:
            ax1, ax2, ay = x2 + 10, boxes[i + 1][0] - 12, 240
            draw.line((ax1, ay, ax2, ay), fill=(7, 148, 188), width=6)
            draw.polygon([(ax2, ay), (ax2 - 18, ay - 12), (ax2 - 18, ay + 12)], fill=(7, 148, 188))
    img.save(FLOW, quality=95)


def add_cover(doc):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(16)
    p.paragraph_format.space_after = Pt(26)
    p.add_run().add_picture(str(LOGO), width=Inches(2.75))

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run("DOCUMENTAÇÃO TÉCNICA")
    set_run_font(r, size=11, color=BLUE, bold=True)

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(8)
    r = p.add_run("Grupo Alessat App")
    set_run_font(r, size=28, color=NAVY, bold=True)

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(22)
    r = p.add_run("Funcionamento do mosaico, APIs utilizadas e controles de carga")
    set_run_font(r, size=14, color=MID_GRAY)

    rows = [
        ("Destinatário", "Intelbras"),
        ("Aplicação", "Grupo Alessat App para Windows"),
        ("Versão documentada", "2.0.1+2"),
        ("Data", "07 de agosto de 2026"),
        ("Finalidade", "Integração técnica e homologação"),
    ]
    table = add_table(doc, ["Documento", "Informação"], rows, [2600, 6760])
    table.rows[0].cells[0].paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.LEFT

    doc.add_paragraph().paragraph_format.space_after = Pt(4)
    add_callout(
        doc,
        "Resumo executivo",
        "O mosaico é uma composição local de câmeras. O aplicativo consulta a API Moovsec para preparar cada SubStream e, quando recebe uma URL HLS, abre um player independente por câmera. A versão 2.0.1 limita a visualização a 32 câmeras e impede chamadas, retentativas e players duplicados.",
    )


def build_document():
    build_flow_diagram()
    doc = Document()
    configure_styles(doc)
    for section in doc.sections:
        configure_page(section)
        configure_header_footer(section)

    doc.core_properties.title = "Documentação Técnica - Grupo Alessat App 2.0.1"
    doc.core_properties.subject = "Funcionamento do mosaico e APIs utilizadas"
    doc.core_properties.author = "Grupo Alessat"
    doc.core_properties.keywords = "Intelbras, mosaico, Moovsec, HLS, API"

    add_cover(doc)
    doc.add_page_break()

    add_heading(doc, "1. Objetivo e escopo", 1)
    add_body(doc, "Este documento descreve como o Grupo Alessat App monta e exibe mosaicos de vídeo, quais serviços Moovsec são consumidos, como uma câmera é transformada em uma sessão HLS e quais proteções existem para evitar carga descontrolada no servidor.")
    add_body(doc, "O escopo cobre o aplicativo Windows versão 2.0.1+2. A implementação e o ciclo de vida dos processos internos dos serviços Moovsec nas portas 3000 e 3010 pertencem ao ambiente servidor e devem ser confirmados pela equipe responsável por esse backend.")

    add_heading(doc, "2. Visão geral da solução", 1)
    add_body(doc, "A solução possui dois papéis distintos:")
    add_bullet(doc, "Aplicativo cliente: autentica o usuário, consulta a frota, mantém a configuração local dos mosaicos e apresenta os vídeos.")
    add_bullet(doc, "Plataforma Moovsec: autentica, fornece dados de frota, prepara o live media e entrega playlists e segmentos HLS.")
    add_callout(doc, "Ponto importante", "O mosaico não é renderizado no servidor como uma imagem única. Cada célula corresponde a um stream independente solicitado pelo aplicativo.", fill="FFF7E6", accent=AMBER)

    add_heading(doc, "3. Fluxo técnico de uma câmera", 1)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(5)
    p.add_run().add_picture(str(FLOW), width=Inches(6.65))
    p = doc.add_paragraph("Figura 1 - Fluxo de preparação e exibição de uma câmera.")
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(8)
    for run in p.runs:
        set_run_font(run, size=9, color=MID_GRAY, italic=True)

    add_number(doc, "O usuário seleciona uma frota, veículo e canal, ou carrega uma frota salva em um mosaico.")
    add_number(doc, "O aplicativo chama o endpoint de live media usando o número serial do dispositivo e o canal.")
    add_number(doc, "Enquanto o HLS está sendo preparado, a API pode responder com um thumbnail. Essa imagem é tratada apenas como estado temporário e não como vídeo final.")
    add_number(doc, "Quando o endereço termina em .m3u8, o aplicativo cria o player e começa a consumir a playlist e seus segmentos no servidor de mídia.")
    add_number(doc, "Ao remover a câmera, trocar o mosaico ou fechar todas as visualizações, o player e suas inscrições são descartados.")

    doc.add_page_break()
    add_heading(doc, "4. Funcionamento do mosaico", 1)
    add_body(doc, "O mosaico é uma estrutura de organização criada no próprio aplicativo. Ele agrupa frotas e, dentro delas, itens formados por veículo e canal. A configuração é armazenada localmente em SharedPreferences, na chave mosaics, e também mantida em cache durante a sessão.")

    add_heading(doc, "4.1 Dados armazenados localmente", 2)
    add_table(
        doc,
        ["Campo", "Exemplo", "Finalidade"],
        [
            ("Nome do mosaico", "Operação noturna", "Identificação da configuração"),
            ("Nome da frota", "Frota frigorificada", "Agrupamento visual"),
            ("Placa", "ABC1D23", "Identificação apresentada ao usuário"),
            ("Device serial", "Serial do equipamento", "Chave usada nas chamadas de live media"),
            ("Canal", "1, 2, 3...", "Seleção da câmera do dispositivo"),
            ("Status", "connected/disconnected", "Aviso de disponibilidade do veículo"),
        ],
        [1900, 2500, 4960],
    )

    add_heading(doc, "4.2 O que não é armazenado", 2)
    add_bullet(doc, "O aplicativo não grava os vídeos ou segmentos HLS no cadastro do mosaico.")
    add_bullet(doc, "A senha de acesso não faz parte da configuração do mosaico.")
    add_bullet(doc, "O token de autenticação é usado durante a sessão e não é incluído no arquivo local do mosaico.")
    add_bullet(doc, "O mosaico não cria um novo vídeo combinado no backend; ele abre uma sessão por célula.")

    add_heading(doc, "4.3 Limite de visualização", 2)
    add_callout(doc, "Requisito do cliente", "Cada instância do aplicativo aceita no máximo 32 câmeras simultâneas. Seleções acima desse limite são truncadas e o usuário recebe uma mensagem informativa.")

    add_heading(doc, "5. APIs e serviços utilizados", 1)
    add_table(
        doc,
        ["Serviço", "Método e rota", "Autenticação", "Uso"],
        [
            ("API principal :5000", "POST /auth/login", "Não autenticada", "Autenticação e obtenção do token"),
            ("API principal :5000", "GET /fleet/all/true", "Bearer token", "Consulta de frotas, veículos e dispositivos"),
            ("Live API :3000", "GET /dvr/{serial}/livemedia", "Bearer token", "Preparação e descoberta do SubStream"),
            ("Mídia :3010", "URL .m3u8 retornada", "Bearer token nos headers do player", "Playlist HLS e segmentos de vídeo"),
        ],
        [1900, 2800, 1900, 2760],
    )

    add_heading(doc, "5.1 Parâmetros do live media", 2)
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Inches(0.25)
    p.paragraph_format.right_indent = Inches(0.25)
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(8)
    r = p.add_run("GET https://moovsec.alessat.com.br:3000/dvr/{deviceSerial}/livemedia\n?channel={canal}&streamType=SubStream&forceStreamType=true&thumbnail=true")
    set_run_font(r, name="Consolas", size=9.2, color=NAVY)
    set_cell = None
    add_body(doc, "streamType=SubStream reduz a carga em comparação ao MainStream. forceStreamType=true solicita o tipo definido. thumbnail=true permite que a API informe um thumbnail enquanto o stream ainda está em preparação.")

    doc.add_page_break()
    add_heading(doc, "6. Controles de carga e proteção do servidor", 1)
    add_body(doc, "A versão 2.0.1 foi estruturada para impedir crescimento descontrolado de requisições e players. Os controles abaixo atuam no cliente:")
    add_table(
        doc,
        ["Controle", "Comportamento", "Efeito esperado"],
        [
            ("Concorrência HTTP", "Máximo de 5 chamadas ativas, em fila FIFO", "Evita rajadas ilimitadas contra as APIs"),
            ("Timeout", "15 segundos com aborto real da requisição", "Libera conexão e vaga ocupada por chamada travada"),
            ("Retentativas", "Máximo de 5 por câmera", "Impede polling infinito de câmeras indisponíveis"),
            ("Backoff", "1, 2, 4 e 8 segundos", "Distribui as tentativas no tempo"),
            ("Deduplicação", "Uma chave por serial + canal", "Impede duas células ou players para a mesma origem"),
            ("Cancelamento lógico", "Respostas antigas são ignoradas", "Evita reabrir streams após troca de mosaico"),
            ("Descarte", "Player e inscrição são encerrados", "Reduz sessões HLS órfãs no cliente"),
            ("Teto operacional", "32 câmeras por instância", "Limita o número de sessões HLS mantidas"),
        ],
        [2100, 3600, 3660],
    )

    add_heading(doc, "6.1 Reconexão após falha", 2)
    add_body(doc, "As reconexões automáticas contínuas foram removidas. Quando um player apresenta erro, a câmera passa ao estado de falha e a interface oferece a ação Reconectar. A ação manual volta a aplicar os mesmos limites de concorrência, tentativas e deduplicação.")

    add_heading(doc, "6.2 Dimensionamento", 2)
    add_callout(doc, "Capacidade potencial", "O limite é aplicado por computador. A carga teórica máxima é 32 sessões multiplicadas pela quantidade de instâncias simultâneas do aplicativo. Exemplo: três computadores podem manter até 96 sessões HLS.", fill="FFF7E6", accent=AMBER)
    add_body(doc, "A capacidade efetiva depende de CPU, memória, banda, quantidade de dispositivos únicos e política de compartilhamento de streams no backend Moovsec.")

    add_heading(doc, "7. Segurança e dados", 1)
    add_bullet(doc, "As URLs configuradas usam HTTPS.")
    add_bullet(doc, "Chamadas autenticadas enviam Authorization: Bearer <token>.")
    add_bullet(doc, "O player envia o token nos headers ao consumir o HLS.")
    add_bullet(doc, "A configuração local do mosaico contém identificação operacional, como placa, serial e canal; deve seguir a política de proteção do equipamento onde o aplicativo é instalado.")
    add_bullet(doc, "O aplicativo não implementa gravação local do conteúdo de vídeo neste fluxo.")

    doc.add_page_break()
    add_heading(doc, "8. Divisão de responsabilidades", 1)
    add_table(
        doc,
        ["Camada", "Responsabilidade"],
        [
            ("Grupo Alessat App", "Limitar solicitações, evitar duplicações, descartar players e apresentar o mosaico."),
            ("API Moovsec :3000", "Preparar ou localizar o live media, aplicar autenticação e devolver o endereço da mídia."),
            ("Servidor de mídia :3010", "Entregar playlist/segmentos HLS e encerrar recursos quando os clientes desconectarem."),
            ("Infraestrutura", "Dimensionar CPU, memória, rede e limites de processos para a quantidade total de clientes."),
        ],
        [2600, 6760],
    )
    add_callout(doc, "Limite desta análise", "O aplicativo não cria processos no servidor diretamente. Ele solicita streams. Se processos continuarem acumulando após o fechamento das câmeras, é necessário verificar o encerramento e a coleta de recursos no backend Moovsec.")

    add_heading(doc, "9. Roteiro de homologação com a Intelbras", 1)
    for item in (
        "Registrar a linha de base de processos, sessões e conexões nas portas 3000 e 3010.",
        "Abrir um mosaico com 1 câmera e confirmar uma única preparação de live media.",
        "Abrir gradualmente mosaicos com 8, 16 e 32 câmeras, observando CPU, memória e conexões.",
        "Trocar rapidamente entre dois mosaicos e confirmar que streams antigos são encerrados.",
        "Simular câmeras offline e confirmar no máximo cinco tentativas por câmera.",
        "Usar Fechar todas e verificar se as sessões retornam à linha de base após o tempo de liberação do backend.",
        "Repetir o teste com a quantidade real de computadores simultâneos.",
        "Registrar tempos de preparação, falhas HTTP, quantidade máxima de processos e tempo de recuperação.",
    ):
        add_number(doc, item)

    add_heading(doc, "10. Critérios de aceite", 1)
    add_bullet(doc, "Nenhuma instância exibe mais de 32 câmeras simultâneas.")
    add_bullet(doc, "Não existem chamadas ilimitadas para câmeras offline.")
    add_bullet(doc, "A mesma combinação serial/canal não gera players concorrentes no cliente.")
    add_bullet(doc, "Trocar ou fechar o mosaico reduz as sessões ao patamar esperado.")
    add_bullet(doc, "O servidor permanece dentro dos limites acordados de CPU, memória, processos e conexões.")

    add_heading(doc, "11. Conclusão", 1)
    add_body(doc, "O Grupo Alessat App utiliza APIs Moovsec para autenticação, consulta da frota e preparação dos streams. O mosaico é uma composição local de até 32 players HLS independentes. A versão 2.0.1 adiciona controles determinísticos de concorrência, timeout, retentativa, deduplicação e descarte, reduzindo o risco de carga indevida causada pelo cliente.")
    add_body(doc, "A homologação final deve correlacionar o comportamento do aplicativo com as métricas dos serviços Moovsec. Esse acompanhamento confirma se o backend encerra os recursos de cada stream depois da desconexão do cliente.")

    add_heading(doc, "Apêndice A - Glossário", 1)
    add_table(
        doc,
        ["Termo", "Definição"],
        [
            ("HLS", "HTTP Live Streaming; protocolo baseado em playlist .m3u8 e segmentos de mídia."),
            ("SubStream", "Versão de menor resolução/bitrate do vídeo, adequada a mosaicos."),
            ("Thumbnail", "Imagem estática temporária retornada enquanto o live media é preparado."),
            ("Player", "Instância local responsável por consumir e decodificar um stream."),
            ("Device serial", "Identificador do equipamento usado para solicitar o canal à API."),
            ("Backoff", "Aumento progressivo do intervalo entre novas tentativas."),
        ],
        [2200, 7160],
    )

    # Avoid orphaned headings and normalize table paragraph behavior.
    for paragraph in doc.paragraphs:
        paragraph.paragraph_format.widow_control = True
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    paragraph.paragraph_format.widow_control = True

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    build_document()
