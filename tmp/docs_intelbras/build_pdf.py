from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    Image,
    KeepTogether,
    ListFlowable,
    ListItem,
    LongTable,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(r"D:\Projetos Pessoais\grupo_alessat_app")
OUTPUT = ROOT / "documentacao" / "Documentacao_Tecnica_Grupo_Alessat_App_2.0.1.pdf"
LOGO = ROOT / "assets" / "logo-login-alessat-dark.png"
FLOW = ROOT / "tmp" / "docs_intelbras" / "fluxo_mosaico.png"

NAVY = colors.HexColor("#153746")
BLUE = colors.HexColor("#0794BC")
LIGHT_BLUE = colors.HexColor("#E8F4F8")
LIGHT_GRAY = colors.HexColor("#F2F4F7")
MID_GRAY = colors.HexColor("#667085")
DARK = colors.HexColor("#1E262D")
BORDER = colors.HexColor("#D0D5DD")
AMBER = colors.HexColor("#A15C00")


styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="BodyTech", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=9.6, leading=12.2, textColor=DARK, spaceAfter=6,
))
styles.add(ParagraphStyle(
    name="BulletTech", parent=styles["BodyTech"],
    leftIndent=14, firstLineIndent=-9, spaceAfter=4,
))
styles.add(ParagraphStyle(
    name="H1Tech", parent=styles["Heading1"], fontName="Helvetica-Bold",
    fontSize=15, leading=18, textColor=BLUE, spaceBefore=12, spaceAfter=7,
    keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="H2Tech", parent=styles["Heading2"], fontName="Helvetica-Bold",
    fontSize=11.5, leading=14, textColor=BLUE, spaceBefore=9, spaceAfter=5,
    keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="SmallTech", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=8.1, leading=10.2, textColor=DARK,
))
styles.add(ParagraphStyle(
    name="TableHeadTech", parent=styles["BodyText"], fontName="Helvetica-Bold",
    fontSize=8.1, leading=9.8, textColor=NAVY,
))
styles.add(ParagraphStyle(
    name="CaptionTech", parent=styles["BodyText"], fontName="Helvetica-Oblique",
    fontSize=8, leading=10, alignment=TA_CENTER, textColor=MID_GRAY, spaceAfter=7,
))
styles.add(ParagraphStyle(
    name="CalloutTech", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=9.3, leading=12, textColor=DARK,
))
styles.add(ParagraphStyle(
    name="CodeTech", parent=styles["Code"], fontName="Courier",
    fontSize=7.8, leading=10, textColor=NAVY, leftIndent=12, rightIndent=12,
    spaceBefore=4, spaceAfter=7,
))


def P(text, style="BodyTech"):
    return Paragraph(text, styles[style])


def bullets(items, ordered=False):
    if not ordered:
        # Use an ASCII marker to avoid depending on the PDF Symbol font.
        return KeepTogether([P("- " + item, "BulletTech") for item in items])

    kwargs = {
        "bulletType": "1",
        "start": "1",
        "leftIndent": 20,
        "bulletFontName": "Helvetica",
        "bulletFontSize": 8.5,
        "spaceAfter": 6,
    }
    return ListFlowable(
        [ListItem(P(item), leftIndent=10) for item in items],
        **kwargs,
    )


def table(headers, rows, widths):
    data = [[P(h, "TableHeadTech") for h in headers]]
    data.extend([[P(str(v), "SmallTech") for v in row] for row in rows])
    t = LongTable(data, colWidths=widths, repeatRows=1, hAlign="CENTER", splitByRow=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), LIGHT_GRAY),
        ("GRID", (0, 0), (-1, -1), 0.45, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return t


def callout(label, text, warning=False):
    accent = AMBER if warning else BLUE
    fill = colors.HexColor("#FFF7E6") if warning else LIGHT_BLUE
    t = Table([[P(f"<b>{label}:</b> {text}", "CalloutTech")]], colWidths=[6.45 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), fill),
        ("BOX", (0, 0), (-1, -1), 1.0, accent),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return KeepTogether([t, Spacer(1, 7)])


def header_footer(canvas, doc):
    canvas.saveState()
    if doc.page > 1:
        canvas.setStrokeColor(BORDER)
        canvas.setLineWidth(0.5)
        canvas.line(0.85 * inch, 10.35 * inch, 7.65 * inch, 10.35 * inch)
        canvas.setFont("Helvetica-Bold", 7.8)
        canvas.setFillColor(NAVY)
        canvas.drawString(0.85 * inch, 10.48 * inch, "GRUPO ALESSAT APP")
        canvas.setFont("Helvetica", 7.8)
        canvas.setFillColor(MID_GRAY)
        canvas.drawRightString(7.65 * inch, 10.48 * inch, "DOCUMENTAÇÃO TÉCNICA | INTELBRAS")
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(MID_GRAY)
    canvas.drawCentredString(4.25 * inch, 0.42 * inch, f"Versão 2.0.1 | 07/08/2026 | Página {doc.page}")
    canvas.restoreState()


def build_story():
    story = []
    story += [Spacer(1, 0.35 * inch), Image(str(LOGO), width=2.75 * inch, height=1.175 * inch), Spacer(1, 0.3 * inch)]
    story.append(P("<font color='#0794BC'><b>DOCUMENTAÇÃO TÉCNICA</b></font>", "BodyTech"))
    story.append(Paragraph("Grupo Alessat App", ParagraphStyle(
        "CoverTitle", fontName="Helvetica-Bold", fontSize=27, leading=31,
        textColor=NAVY, spaceAfter=7,
    )))
    story.append(Paragraph("Funcionamento do mosaico, APIs utilizadas e controles de carga", ParagraphStyle(
        "CoverSubtitle", fontName="Helvetica", fontSize=13, leading=17,
        textColor=MID_GRAY, spaceAfter=22,
    )))
    story.append(table(
        ["Documento", "Informação"],
        [
            ("Destinatário", "Intelbras"),
            ("Aplicação", "Grupo Alessat App para Windows"),
            ("Versão documentada", "2.0.1+2"),
            ("Data", "07 de agosto de 2026"),
            ("Finalidade", "Integração técnica e homologação"),
        ],
        [1.8 * inch, 4.5 * inch],
    ))
    story += [Spacer(1, 10), callout(
        "Resumo executivo",
        "O mosaico é uma composição local de câmeras. O aplicativo consulta a API Moovsec para preparar cada SubStream e, quando recebe uma URL HLS, abre um player independente por câmera. A versão 2.0.1 limita a visualização a 32 câmeras e impede chamadas, retentativas e players duplicados.",
    ), PageBreak()]

    story += [P("1. Objetivo e escopo", "H1Tech")]
    story.append(P("Este documento descreve como o Grupo Alessat App monta e exibe mosaicos de vídeo, quais serviços Moovsec são consumidos, como uma câmera é transformada em uma sessão HLS e quais proteções existem para evitar carga descontrolada no servidor."))
    story.append(P("O escopo cobre o aplicativo Windows versão 2.0.1+2. O ciclo de vida dos processos internos dos serviços Moovsec nas portas 3000 e 3010 pertence ao ambiente servidor e deve ser confirmado pela equipe responsável pelo backend."))
    story += [P("2. Visão geral da solução", "H1Tech")]
    story.append(bullets([
        "<b>Aplicativo cliente:</b> autentica, consulta a frota, mantém a configuração local dos mosaicos e apresenta os vídeos.",
        "<b>Plataforma Moovsec:</b> autentica, fornece dados de frota, prepara o live media e entrega playlists e segmentos HLS.",
    ]))
    story.append(callout("Ponto importante", "O mosaico não é renderizado no servidor como uma imagem única. Cada célula corresponde a um stream independente solicitado pelo aplicativo.", warning=True))
    story += [P("3. Fluxo técnico de uma câmera", "H1Tech"), Image(str(FLOW), width=6.65 * inch, height=1.77 * inch), P("Figura 1 - Fluxo de preparação e exibição de uma câmera.", "CaptionTech")]
    story.append(bullets([
        "O usuário seleciona uma frota, veículo e canal, ou carrega uma frota salva em um mosaico.",
        "O aplicativo chama o endpoint de live media usando o serial e o canal.",
        "A API pode responder temporariamente com um thumbnail enquanto prepara o HLS.",
        "Ao receber uma URL .m3u8, o aplicativo cria o player e consome a playlist e os segmentos.",
        "Ao remover a câmera ou trocar o mosaico, o player e suas inscrições são descartados.",
    ], ordered=True))

    story += [PageBreak(), P("4. Funcionamento do mosaico", "H1Tech")]
    story.append(P("O mosaico é uma estrutura criada no próprio aplicativo. Ele agrupa frotas e itens formados por veículo e canal. A configuração é armazenada localmente em SharedPreferences, na chave mosaics, e mantida em cache durante a sessão."))
    story += [P("4.1 Dados armazenados localmente", "H2Tech")]
    story.append(table(
        ["Campo", "Exemplo", "Finalidade"],
        [
            ("Nome do mosaico", "Operação noturna", "Identificação da configuração"),
            ("Nome da frota", "Frota frigorificada", "Agrupamento visual"),
            ("Placa", "ABC1D23", "Identificação apresentada ao usuário"),
            ("Device serial", "Serial do equipamento", "Chave usada nas chamadas de live media"),
            ("Canal", "1, 2, 3...", "Seleção da câmera do dispositivo"),
            ("Status", "connected/disconnected", "Aviso de disponibilidade"),
        ],
        [1.35 * inch, 1.75 * inch, 3.25 * inch],
    ))
    story += [P("4.2 O que não é armazenado", "H2Tech")]
    story.append(bullets([
        "Vídeos ou segmentos HLS não são gravados no cadastro do mosaico.",
        "A senha não faz parte da configuração local.",
        "O token é usado durante a sessão e não é incluído no mosaico.",
        "Não é criado um vídeo combinado no backend; existe uma sessão por célula.",
    ]))
    story += [P("4.3 Limite de visualização", "H2Tech"), callout("Requisito do cliente", "Cada instância aceita no máximo 32 câmeras simultâneas. Seleções acima do limite são truncadas e o usuário recebe uma mensagem.")]

    story += [P("5. APIs e serviços utilizados", "H1Tech")]
    story.append(table(
        ["Serviço", "Método e rota", "Autenticação", "Uso"],
        [
            ("API :5000", "POST /auth/login", "Não autenticada", "Autenticação e token"),
            ("API :5000", "GET /fleet/all/true", "Bearer token", "Frotas, veículos e dispositivos"),
            ("Live API :3000", "GET /dvr/{serial}/livemedia", "Bearer token", "Preparação do SubStream"),
            ("Mídia :3010", "URL .m3u8 retornada", "Bearer token no player", "Playlist e segmentos HLS"),
        ],
        [1.12 * inch, 2.0 * inch, 1.35 * inch, 1.88 * inch],
    ))
    story += [P("5.1 Parâmetros do live media", "H2Tech"), P("GET https://moovsec.alessat.com.br:3000/dvr/{deviceSerial}/livemedia<br/>?channel={canal}&amp;streamType=SubStream&amp;forceStreamType=true&amp;thumbnail=true", "CodeTech")]
    story.append(P("SubStream reduz a carga em comparação ao MainStream. thumbnail=true permite informar uma imagem temporária enquanto o stream é preparado."))

    story += [PageBreak(), P("6. Controles de carga e proteção do servidor", "H1Tech")]
    story.append(P("A versão 2.0.1 impede o crescimento descontrolado de requisições e players por meio dos controles abaixo:"))
    story.append(table(
        ["Controle", "Comportamento", "Efeito esperado"],
        [
            ("Concorrência HTTP", "Máximo de 5 chamadas em fila FIFO", "Evita rajadas ilimitadas"),
            ("Timeout", "15 s com aborto real", "Libera conexão e vaga travada"),
            ("Retentativas", "Máximo de 5 por câmera", "Impede polling infinito"),
            ("Backoff", "1, 2, 4 e 8 segundos", "Distribui tentativas no tempo"),
            ("Deduplicação", "Uma chave por serial + canal", "Impede players duplicados"),
            ("Cancelamento lógico", "Respostas antigas são ignoradas", "Não reabre mosaicos fechados"),
            ("Descarte", "Player e inscrição são encerrados", "Reduz sessões órfãs"),
            ("Teto", "32 câmeras por instância", "Limita sessões HLS"),
        ],
        [1.4 * inch, 2.55 * inch, 2.4 * inch],
    ))
    story += [P("6.1 Reconexão após falha", "H2Tech")]
    story.append(P("Reconexões automáticas contínuas foram removidas. Após erro, a interface oferece Reconectar; a ação volta a aplicar concorrência, tentativas e deduplicação."))
    story += [P("6.2 Dimensionamento", "H2Tech"), callout("Capacidade potencial", "O limite é por computador. A carga máxima teórica é 32 vezes o número de instâncias simultâneas. Três computadores podem manter até 96 sessões HLS.", warning=True)]
    story.append(P("A capacidade efetiva depende de CPU, memória, banda, dispositivos únicos e política de compartilhamento de streams no backend."))
    story += [P("7. Segurança e dados", "H1Tech")]
    story.append(bullets([
        "As URLs configuradas usam HTTPS.",
        "Chamadas autenticadas enviam Authorization: Bearer &lt;token&gt;.",
        "O player envia o token nos headers ao consumir o HLS.",
        "O mosaico contém placa, serial e canal; o computador deve seguir a política de proteção aplicável.",
        "O fluxo não implementa gravação local do conteúdo de vídeo.",
    ]))

    story += [PageBreak(), P("8. Divisão de responsabilidades", "H1Tech")]
    story.append(table(
        ["Camada", "Responsabilidade"],
        [
            ("Grupo Alessat App", "Limitar solicitações, evitar duplicações, descartar players e apresentar o mosaico."),
            ("API Moovsec :3000", "Preparar/localizar live media, autenticar e devolver o endereço."),
            ("Servidor :3010", "Entregar HLS e encerrar recursos após desconexão."),
            ("Infraestrutura", "Dimensionar CPU, memória, rede e limites de processos."),
        ],
        [1.85 * inch, 4.5 * inch],
    ))
    story.append(callout("Limite desta análise", "O aplicativo não cria processos no servidor diretamente. Se processos acumularem após o fechamento das câmeras, deve-se verificar o encerramento e a coleta de recursos no backend Moovsec."))
    story += [P("9. Roteiro de homologação", "H1Tech")]
    story.append(bullets([
        "Registrar a linha de base de processos, sessões e conexões nas portas 3000 e 3010.",
        "Abrir mosaicos com 1, 8, 16 e 32 câmeras, observando CPU, memória e conexões.",
        "Trocar rapidamente entre mosaicos e confirmar o encerramento dos streams antigos.",
        "Simular câmeras offline e confirmar no máximo cinco tentativas por câmera.",
        "Usar Fechar todas e verificar o retorno das sessões à linha de base.",
        "Repetir com a quantidade real de computadores simultâneos.",
        "Registrar tempos de preparação, falhas HTTP, pico de processos e tempo de recuperação.",
    ], ordered=True))
    story += [P("10. Critérios de aceite", "H1Tech")]
    story.append(bullets([
        "Nenhuma instância exibe mais de 32 câmeras.",
        "Não existem chamadas ilimitadas para câmeras offline.",
        "A mesma combinação serial/canal não gera players concorrentes.",
        "Fechar o mosaico reduz as sessões ao patamar esperado.",
        "O servidor permanece dentro dos limites acordados de recursos.",
    ]))
    story += [P("11. Conclusão", "H1Tech")]
    story.append(P("O mosaico é uma composição local de até 32 players HLS independentes. A versão 2.0.1 adiciona controles determinísticos de concorrência, timeout, retentativa, deduplicação e descarte, reduzindo o risco de carga indevida causada pelo cliente."))
    story.append(P("A homologação deve correlacionar o comportamento do aplicativo com as métricas Moovsec para confirmar que o backend encerra os recursos de cada stream após a desconexão."))
    story += [P("Apêndice A - Glossário", "H1Tech")]
    story.append(table(
        ["Termo", "Definição"],
        [
            ("HLS", "HTTP Live Streaming; playlist .m3u8 e segmentos de mídia."),
            ("SubStream", "Vídeo de menor resolução/bitrate, adequado a mosaicos."),
            ("Thumbnail", "Imagem temporária enquanto o live media é preparado."),
            ("Player", "Instância local que consome e decodifica um stream."),
            ("Device serial", "Identificador usado para solicitar o canal."),
            ("Backoff", "Aumento progressivo entre novas tentativas."),
        ],
        [1.55 * inch, 4.8 * inch],
    ))
    return story


def build_pdf():
    doc = BaseDocTemplate(
        str(OUTPUT), pagesize=LETTER,
        leftMargin=0.85 * inch, rightMargin=0.85 * inch,
        topMargin=1.0 * inch, bottomMargin=0.72 * inch,
        title="Documentação Técnica - Grupo Alessat App 2.0.1",
        author="Grupo Alessat",
        subject="Funcionamento do mosaico e APIs utilizadas",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="normal")
    doc.addPageTemplates([PageTemplate(id="main", frames=frame, onPage=header_footer)])
    doc.build(build_story())
    print(OUTPUT)


if __name__ == "__main__":
    build_pdf()
