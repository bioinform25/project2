#!/usr/bin/env python3
"""Rebuild the dry-lab summary deck to match the visual style of
'260713 lab meeting.pptx' (VS-Code-dark code boxes, Arial titles,
white-bordered result boxes/tables, Courier/Calibri results)."""

import os
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

BASE = r"C:\Users\SAMSUNG\Desktop\project2"
FIG = os.path.join(BASE, "figures")
OUT = os.path.join(BASE, "presentation", "dry_lab_summary.pptx")

# ---- palette (matched to the reference template) ----
BLACK = RGBColor(0, 0, 0)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
CODE_BG = RGBColor(0x1E, 0x1E, 0x1E)
CODE_BORDER = RGBColor(0x45, 0x45, 0x45)
GREEN_COMMENT = RGBColor(0x6A, 0x99, 0x55)
YELLOW_KEY = RGBColor(0xDC, 0xDC, 0xAA)
GRAY_CODE = RGBColor(0xD4, 0xD4, 0xD4)

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)
BLANK = prs.slide_layouts[6]
SLIDE_W = prs.slide_width
SLIDE_H = prs.slide_height


def EI(inches):
    """Inches -> integer EMU, safe against float division bugs."""
    return Emu(int(Inches(inches)))


def new_slide():
    return prs.slides.add_slide(BLANK)


def set_run(run, text, size, bold=False, italic=False, color=BLACK, font="Arial"):
    run.text = text
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.color.rgb = color
    run.font.name = font


def add_content_title(slide, text):
    """Top title bar matching the reference: (0.4,0.15,12.5,0.55), Arial 20 bold black."""
    tb = slide.shapes.add_textbox(EI(0.4), EI(0.15), EI(12.5), EI(0.55))
    tf = tb.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    r = p.add_run()
    set_run(r, text, 20, bold=True)
    return tb


def add_section_header(title, subtitle):
    """Divider slide matching the reference 'PROJECT N' slides: big bold title +
    smaller subtitle, centered around y=3.0."""
    s = new_slide()
    tb = s.shapes.add_textbox(EI(0.8), EI(3.0), EI(11.7), EI(2.0))
    tf = tb.text_frame
    tf.word_wrap = True
    p0 = tf.paragraphs[0]
    r0 = p0.add_run()
    set_run(r0, title, 32, bold=True)
    p1 = tf.add_paragraph()
    p1.space_before = Pt(10)
    r1 = p1.add_run()
    set_run(r1, subtitle, 16)
    return s


def add_overview_slide(title, lines):
    """Title + paragraph body matching reference slide 2 (Overall Study Flow):
    title bar, then a body textbox of '- ' prefixed lines."""
    s = new_slide()
    add_content_title(s, title)
    tb = s.shapes.add_textbox(EI(0.6), EI(1.2), EI(12.1), EI(5.9))
    tf = tb.text_frame
    tf.word_wrap = True
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        if line == "":
            p.space_before = Pt(8)
            r = p.add_run()
            set_run(r, "", 14)
            continue
        r = p.add_run()
        set_run(r, line, 14)
        p.line_spacing = 1.2
    return s


def add_code_box(slide, left_in, top_in, width_in, height_in, lines):
    """lines: list of (text, kind) with kind in {'comment','key','code'}.
    Matches reference: rounded rect, fill 1E1E1E, border 454545, Consolas 7pt,
    108% line spacing, vertically centered; comment lines green, key lines
    yellow, regular code gray; first line centered if it's a comment header."""
    color_map = {"comment": GREEN_COMMENT, "key": YELLOW_KEY, "code": GRAY_CODE}
    box = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE,
                                  EI(left_in), EI(top_in), EI(width_in), EI(height_in))
    box.adjustments[0] = 0.04
    box.fill.solid()
    box.fill.fore_color.rgb = CODE_BG
    box.line.color.rgb = CODE_BORDER
    box.line.width = Pt(0.75)
    tf = box.text_frame
    tf.word_wrap = True
    tf.margin_left = Inches(0.16)
    tf.margin_right = Inches(0.16)
    tf.margin_top = Inches(0.1)
    tf.margin_bottom = Inches(0.1)
    from pptx.enum.text import MSO_ANCHOR
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    for i, (text, kind) in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.line_spacing = 1.08
        p.space_after = Pt(0)
        if i == 0 and kind == "comment":
            p.alignment = PP_ALIGN.CENTER
        r = p.add_run()
        set_run(r, text, 7, color=color_map[kind], font="Consolas")
    return box


def add_explanation(slide, left_in, top_in, width_in, height_in, text):
    """Plain textbox, no border: Arial 11.5, matching reference explanation box."""
    tb = slide.shapes.add_textbox(EI(left_in), EI(top_in), EI(width_in), EI(height_in))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_left = 0
    tf.margin_right = 0
    tf.margin_top = 0
    lines = text.split("\n")
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.line_spacing = 1.15
        r = p.add_run()
        set_run(r, line, 11.5)
    return tb


def add_result_table(slide, left_in, top_in, width_in, height_in, headers, rows, font_size=10):
    """White bg, bold Calibri header, black border - matching reference tables."""
    n_rows = len(rows) + 1
    n_cols = len(headers)
    gshape = slide.shapes.add_table(n_rows, n_cols, EI(left_in), EI(top_in),
                                     EI(width_in), EI(height_in))
    table = gshape.table
    for j, h in enumerate(headers):
        cell = table.cell(0, j)
        cell.text = ""
        cell.fill.solid()
        cell.fill.fore_color.rgb = WHITE
        r = cell.text_frame.paragraphs[0].add_run()
        set_run(r, str(h), font_size, bold=True, font="Calibri")
    for i, row in enumerate(rows, start=1):
        for j, val in enumerate(row):
            cell = table.cell(i, j)
            cell.text = ""
            cell.fill.solid()
            cell.fill.fore_color.rgb = WHITE
            r = cell.text_frame.paragraphs[0].add_run()
            set_run(r, str(val), font_size, font="Calibri")
    return gshape


def add_result_image(slide, left_in, top_in, width_in, height_in, img_path):
    max_w = EI(width_in)
    max_h = EI(height_in)
    pic = slide.shapes.add_picture(img_path, EI(left_in), EI(top_in), height=max_h)
    if pic.width > max_w:
        ratio = max_w / pic.width
        pic.width = int(max_w)
        pic.height = int(pic.height * ratio)
    pic.left = int(EI(left_in) + (max_w - pic.width) / 2)
    pic.top = int(EI(top_in) + (max_h - pic.height) / 2)
    return pic


def content_slide(title, code_lines, explanation, result_image=None, result_table=None):
    """Full layout matching the reference content slides."""
    s = new_slide()
    add_content_title(s, title)
    code_h = 4.0 if (result_table or result_image) else 4.0
    add_code_box(s, 0.4, 1.05, 7.35, 4.15, code_lines)
    add_explanation(s, 7.95, 1.05, 4.98, 1.3, explanation)
    if result_image:
        add_result_image(s, 7.95, 2.55, 4.98, 3.65, result_image)
    elif result_table:
        headers, rows = result_table
        row_h = 3.65 / (len(rows) + 1)
        add_result_table(s, 7.95, 2.55, 4.98, 3.65, headers, rows)
    return s


# =====================================================================
# SLIDE 1: TITLE
# =====================================================================
s = new_slide()
tb = s.shapes.add_textbox(EI(1.0), EI(2.2), EI(11.3), EI(3.5))
tf = tb.text_frame
tf.word_wrap = True
p0 = tf.paragraphs[0]
r0 = p0.add_run()
set_run(r0, "PHMG → HSF2 → NETosis Hypothesis: Dry-Lab Verification", 30, bold=True)
p1 = tf.add_paragraph()
p1.space_before = Pt(16)
r1 = p1.add_run()
set_run(r1, "Public human fibrosis (GSE135251, GSE14323, GSE47460, GSE53845) + HCC-ICI "
            "(GSE215011, GSE279750, GSE235863) cohort analysis", 18)
p2 = tf.add_paragraph()
p2.space_before = Pt(10)
r2 = p2.add_run()
set_run(r2, "github.com/bioinform25/project2", 13)

# =====================================================================
# SLIDE 2: OVERVIEW
# =====================================================================
add_overview_slide("Overall Study Flow", [
    "- Lab's wet-lab experiments: PHMG 6 mg/kg in vivo mouse neutrophil RNA-seq -> HSF2 "
    "ranked #1 upstream TF of upregulated genes; ex vivo PHMG 3 ug/mL, 6h -> Western blot "
    "shows a thicker HSF2 band.",
    "- Working hypothesis: PHMG -> HSF2 activation -> N2 (immunosuppressive) neutrophil "
    "polarization -> NETosis-gene induction -> fibrosis / HCC immune evasion.",
    "- This deck: before more wet-lab work, tests the population-level prediction of that "
    "hypothesis (HSF2 up -> NETosis-core genes up) using 4 independent public human fibrosis "
    "cohorts, then extends to 3 independent HCC immunotherapy-response cohorts.",
    "- 12 R scripts total (scripts/00-12 in the repo), all pre-registered before results were "
    "seen: primary endpoint, replication rule, specificity control, in silico TF check, and "
    "meta-analyses throughout.",
    "- This PPT walks through every script's code, actual output, and a one-line "
    "interpretation, in the order the analysis was actually run.",
])

# =====================================================================
# SLIDE 3: SECTION HEADER - PART 1
# =====================================================================
add_section_header(
    "PART 1 — Human Fibrosis Cohorts",
    "Does HSF2 positively correlate with NETosis-core genes in fibrotic liver/lung tissue?"
)

# =====================================================================
# SLIDE 4: PRE-SPECIFIED PLAN
# =====================================================================
code = [
    ("# scripts/00_functions.R - plan written BEFORE any result was seen", "comment"),
    ("NET_CORE     <- c(\"PADI4\", \"ELANE\", \"MPO\")", "key"),
    ("NET_EXTENDED <- c(NET_CORE, \"CTSG\", \"LTF\", \"CAMP\", \"DEFA4\",", "code"),
    ("                   \"AZU1\", \"ITGAM\", \"NCF2\", \"S100A12\", \"LCN2\")", "code"),
    ("TARGET_TF    <- \"HSF2\"", "key"),
    ("", "code"),
    ("# Primary endpoint: Spearman rho(HSF2, NET_core_score)", "comment"),
    ("#   within diseased/fibrotic samples, alpha = 0.05", "comment"),
    ("# Replication rule: primary + replication cohort must agree", "comment"),
    ("#   in sign AND both be nominally significant (p<0.05)", "comment"),
]
content_slide(
    "00_functions.R — Pre-Specified Hypothesis & Analysis Plan",
    code,
    "If HSF2 drives NETosis-gene expression, HSF2 should POSITIVELY correlate with "
    "PADI4/ELANE/MPO in fibrotic tissue, reproducibly across independent cohorts. This plan "
    "was fixed before any correlation was computed.",
    result_table=(
        ["Cohort", "Organ", "Role", "n (fibrotic)"],
        [
            ["GSE135251", "Liver", "Primary", "206"],
            ["GSE14323", "Liver", "Replication", "96"],
            ["GSE47460", "Lung", "Primary", "122"],
            ["GSE53845", "Lung", "Replication", "40"],
        ],
    ),
)

# =====================================================================
# SLIDE 5: GSE135251 (liver, primary)
# =====================================================================
code = [
    ("# scripts/01_liver_GSE135251.R (RNA-seq, n=206 NAFLD)", "comment"),
    ("net_core_score <- panel_score(expr_panel, NET_CORE, min_genes = 2)", "code"),
    ("df_nafld <- df[df$disease == \"NAFLD\", ]", "code"),
    ("", "code"),
    ("results$primary <- spearman_report(", "key"),
    ("    df_nafld$HSF2, df_nafld$NET_core,", "key"),
    ("    \"HSF2 vs NET_core (NAFLD subset, primary)\")", "key"),
]
content_slide(
    "01_liver_GSE135251.R — Liver, Primary Cohort (n=206)",
    code,
    "Result is OPPOSITE the original hypothesis: HSF2 correlates negatively with the "
    "NETosis-core score in fibrotic liver tissue.",
    result_image=os.path.join(FIG, "liver_GSE135251_HSF2_vs_NETcore.png"),
)

# =====================================================================
# SLIDE 6: GSE14323 (liver, replication)
# =====================================================================
code = [
    ("# scripts/02_liver_GSE14323.R (Affymetrix, independent platform)", "comment"),
    ("df_disease <- df[df$tissue != \"Normal\", ]  # n=96", "code"),
    ("", "code"),
    ("results$primary <- spearman_report(", "key"),
    ("    df_disease$HSF2, df_disease$NET_core,", "key"),
    ("    \"HSF2 vs NET_core (diseased subset, replication)\")", "key"),
    ("", "code"),
    ("# Replication rule (same sign + both p<0.05): MET", "comment"),
]
content_slide(
    "02_liver_GSE14323.R — Liver, Replication Cohort (n=96)",
    code,
    "Independent platform, independent patients — same negative direction, much stronger "
    "(rho=-0.550, p=6.2e-09). Formally REPLICATES the liver finding.",
    result_image=os.path.join(FIG, "liver_GSE14323_HSF2_vs_NETcore.png"),
)

# =====================================================================
# SLIDE 7: GSE47460 (lung, primary)
# =====================================================================
code = [
    ("# scripts/03_lung_GSE47460.R (Agilent, n=122 UIP/IPF)", "comment"),
    ("df_fibrotic <- df[df$group == \"UIP_IPF\", ]", "code"),
    ("", "code"),
    ("results$primary <- spearman_report(", "key"),
    ("    df_fibrotic$HSF2, df_fibrotic$NET_core,", "key"),
    ("    \"HSF2 vs NET_core (UIP/IPF subset, primary)\")", "key"),
]
content_slide(
    "03_lung_GSE47460.R — Lung, Primary Cohort (n=122)",
    code,
    "Different organ (lung, not liver), different platform — same negative direction, "
    "highly significant (rho=-0.392, p=8.1e-06). Pattern is not liver-specific.",
    result_image=os.path.join(FIG, "lung_GSE47460_HSF2_vs_NETcore.png"),
)

# =====================================================================
# SLIDE 8: GSE53845 (lung, replication)
# =====================================================================
code = [
    ("# scripts/04_lung_GSE53845.R (Agilent 2-color, n=40 IPF)", "comment"),
    ("df_ipf <- df[df$diagnosis == \"IPF\", ]", "code"),
    ("", "code"),
    ("results$primary <- spearman_report(", "key"),
    ("    df_ipf$HSF2, df_ipf$NET_core,", "key"),
    ("    \"HSF2 vs NET_core (IPF subset, replication)\")", "key"),
    ("", "code"),
    ("# rho=-0.050, p=0.760 (n.s.) - same sign, underpowered (n=40)", "comment"),
]
content_slide(
    "04_lung_GSE53845.R — Lung, Replication Cohort (n=40)",
    code,
    "Direction still negative but n=40 is underpowered - not individually significant. "
    "Treated as \"no information,\" not contradicting evidence; carried into the meta-analysis.",
    result_image=os.path.join(FIG, "lung_GSE53845_HSF2_vs_NETcore.png"),
)

# =====================================================================
# SLIDE 9: META-ANALYSIS (KEY FINDING)
# =====================================================================
code = [
    ("# scripts/05_meta_analysis.R", "comment"),
    ("# from-scratch Fisher-z / DerSimonian-Laird random-effects", "comment"),
    ("meta_all <- meta_cor_DL(primary_df$rho, primary_df$n, primary_df$cohort)", "key"),
    ("", "code"),
    ("cat(sprintf(\"pooled rho=%.3f, 95%% CI [%.3f,%.3f], p=%.3g", "code"),
    ("Heterogeneity: I^2=%.1f%%\", meta_all$pooled_rho, meta_all$ci_lo,", "code"),
    ("meta_all$ci_hi, meta_all$p_value, meta_all$I2))", "code"),
]
content_slide(
    "05_meta_analysis.R — KEY FINDING: 4-Cohort Meta-Analysis",
    code,
    "Pooled rho=-0.308 (p=0.010) IS significant and OPPOSITE the hypothesis, even though "
    "GSE53845 alone was underpowered. But I^2=83.5% (high heterogeneity): significance says "
    "the direction is real; heterogeneity says the effect SIZE is not uniform across cohorts "
    "— two separate questions. The wet-lab time-course is what settles the magnitude question.",
    result_image=os.path.join(FIG, "FOREST_HSF2_vs_NETcore_all_cohorts.png"),
)

# =====================================================================
# SLIDE 10: SPECIFICITY CONTROL
# =====================================================================
code = [
    ("# scripts/06_specificity_check_PTPRC.R", "comment"),
    ("# Is this just \"more immune infiltrate dilutes HSF2 signal\"?", "comment"),
    ("# Test against PTPRC (CD45, pan-leukocyte marker):", "comment"),
    ("r1_ptprc   <- spearman_report(df1_dis$HSF2, df1_dis$PTPRC, ...)", "key"),
    ("r1_netcore <- spearman_report(df1_dis$HSF2, df1_dis$NET_core, ...)", "key"),
]
content_slide(
    "06_specificity_check_PTPRC.R — Ruling Out a Trivial Artifact",
    code,
    "HSF2 rises WITH overall immune infiltration (PTPRC, positive) but falls specifically "
    "with NETosis-core genes (negative) — opposite directions. Rules out the trivial "
    "\"more immune cells = less relative HSF2\" explanation.",
    result_table=(
        ["Cohort", "HSF2 vs PTPRC", "HSF2 vs NET_core"],
        [
            ["GSE135251", "+0.178 (p=0.010)", "-0.145 (p=0.038)"],
            ["GSE14323", "+0.448 (p=4.7e-06)", "-0.550 (p=6.2e-09)"],
        ],
    ),
)

# =====================================================================
# SLIDE 11: CROSS-COHORT GENE CONSISTENCY
# =====================================================================
code = [
    ("# scripts/08_cross_cohort_gene_consistency.R", "comment"),
    ("# Which individual NETosis genes move with HSF2 the SAME", "comment"),
    ("# direction in all 4 cohorts, vs. which flip liver<->lung?", "comment"),
    ("consistency$n_cohorts_sig_FDR05 <- rowSums(consistency[, fdr_cols] < 0.05)", "code"),
    ("consistency$direction_consistent <-", "key"),
    ("    (consistency$n_negative == consistency$n_cohorts_tested) |", "key"),
    ("    (consistency$n_positive == consistency$n_cohorts_tested)", "key"),
]
content_slide(
    "08_cross_cohort_gene_consistency.R — Which Genes Drive This",
    code,
    "CAMP/MPO/DEFA4 (+ PADI4/ELANE with 1 small exception) move consistently negative with "
    "HSF2 in all 4 cohorts. LTF/NCF2/ITGAM/LCN2 actually flip sign between liver and lung — "
    "possibly not neutrophil-specific (e.g. LCN2 is also made by stressed hepatocytes).",
    result_table=(
        ["Gene", "GSE135251", "GSE14323", "GSE47460", "GSE53845", "Direction"],
        [
            ["CAMP", "-0.056", "-0.459", "-0.457", "-0.529", "Consistent (-)"],
            ["MPO", "-0.025", "-0.277", "-0.320", "-0.412", "Consistent (-)"],
            ["DEFA4", "-0.090", "-0.337", "-0.328", "-0.097", "Consistent (-)"],
            ["PADI4", "-0.120", "-0.496", "-0.205", "+0.181", "3 neg/1 pos (ns)"],
            ["ELANE", "-0.192", "-0.422", "-0.348", "+0.075", "3 neg/1 pos (ns)"],
        ],
    ),
)

# =====================================================================
# SLIDE 12: CHEA3 IN SILICO CHECK
# =====================================================================
code = [
    ("# scripts/09_chea3_analysis.R", "comment"),
    ("# Does any existing ChIP-seq/co-expression DB already show", "comment"),
    ("# HSF2 upstream of these genes?", "comment"),
    ("res <- httr::POST(", "key"),
    ("  url = \"https://maayanlab.cloud/chea3/api/enrich/\",", "key"),
    ("  body = list(query_name = query_name, gene_set = as.list(genes)))", "key"),
]
content_slide(
    "09_chea3_analysis.R — No Existing Evidence for This Regulation",
    code,
    "Across 8 evidence libraries (ChIP-seq + co-expression + literature), HSF2 is never a "
    "plausible top regulator of this gene set. Either a repressive relationship these tools "
    "can't detect, or genuinely unstudied territory (blue ocean).",
    result_table=(
        ["Library", "HSF2 rank", "Total TFs", "Overlap"],
        [
            ["Integrated mean rank", "1444", "1632", "-"],
            ["ARCHS4 co-expression", "1209", "1628", "0"],
            ["GTEx co-expression", "1417", "1607", "0"],
            ["ENCODE ChIP-seq", "not returned", "118", "-"],
            ["ReMap ChIP-seq", "not returned", "297", "-"],
        ],
    ),
)

# =====================================================================
# SLIDE 13: SECTION HEADER - PART 2
# =====================================================================
add_section_header(
    "PART 2 — HCC Immunotherapy Cohorts",
    "HCC = liver cancer, ICI = immune-checkpoint-inhibitor drugs. Does tumor HSF2 relate to "
    "whether real patients respond to immunotherapy?"
)

# =====================================================================
# SLIDE 14: GATE-CHECK + GSE215011
# =====================================================================
code = [
    ("# GSE140901 (originally planned dataset) - GATE-CHECK first:", "comment"),
    ("# 785-gene NanoString panel - does it measure our genes?", "comment"),
    ("zcat GSE140901_processed_data.txt.gz | grep -w \"HSF2\"", "key"),
    ("# >>> no output - HSF2 NOT in panel; PADI4/MPO also missing", "comment"),
    ("# ==> EXCLUDED, not force-fit with a substitute readout", "comment"),
    ("", "code"),
    ("# scripts/07_hcc_ICI_GSE215011.R (nivolumab monotherapy, n=10)", "comment"),
    ("wilcox_report(df$HSF2, df$group, \"HSF2: Responder vs Non-responder\")", "key"),
]
content_slide(
    "Dataset Gate-Check + First Cohort: GSE215011 (n=10)",
    code,
    "Originally planned dataset didn't measure HSF2 at all - checked directly, excluded "
    "rather than substituting. Found GSE215011 instead (real RNA-seq). Alone, n=10 is too "
    "small to reach significance (rank-biserial r=0.44, p=0.30).",
    result_image=os.path.join(FIG, "hcc_ICI_GSE215011_HSF2_vs_NETcore.png"),
)

# =====================================================================
# SLIDE 15: GSE279750 + GSE235863
# =====================================================================
code = [
    ("# scripts/10_hcc_ICI_GSE279750.R (anti-PD-L1 combo, post-tx, n=10)", "comment"),
    ("wilcox_report(df$HSF2, df$group, \"HSF2: Responder vs Non-responder\")", "key"),
    ("# >>> rank-biserial r=-0.92, p=0.025 (responders have LOWER HSF2)", "comment"),
    ("", "code"),
    ("# scripts/11_hcc_ICI_GSE235863.R (anti-PD-1+lenvatinib, n=15)", "comment"),
    ("wilcox_report(df$HSF2, df$group, \"HSF2: Responder vs Non-responder\")", "key"),
    ("# >>> rank-biserial r=-0.73, p=0.043 (same direction, also sig.)", "comment"),
]
content_slide(
    "Two More Independent HCC-ICI Cohorts (n=10, n=15)",
    code,
    "Patients with LOWER tumor HSF2 responded better to combination immunotherapy in both "
    "cohorts (both p<0.05). Note: both are combination-regimen, post-treatment cohorts - "
    "different design from GSE215011's monotherapy.",
    result_image=os.path.join(FIG, "hcc_ICI_GSE279750_HSF2_by_response.png"),
)

# =====================================================================
# SLIDE 16: ICI POOLED META-ANALYSIS
# =====================================================================
code = [
    ("# scripts/12_hcc_ICI_pooled_summary.R", "comment"),
    ("# rank-biserial r = scale-free Wilcoxon effect size,", "comment"),
    ("# valid across differently-normalized expression scales", "comment"),
    ("meta <- meta_cor_DL(summary_df$r_rb, summary_df$n, summary_df$cohort)", "key"),
    ("", "code"),
    ("# >>> Pooled (random-effects): r=-0.59, p=0.22 (I^2=87.1%)", "comment"),
    ("# ==> 2/3 individually significant, NOT a confirmed pooled finding", "comment"),
]
content_slide(
    "12_hcc_ICI_pooled_summary.R — Suggestive Lead, Not Yet Proven",
    code,
    "IMPORTANT for grant \"preliminary data\" framing: 2 of 3 cohorts individually "
    "significant, but formal pooled meta-analysis is NOT significant (p=0.22, high "
    "heterogeneity). Present as a promising signal needing a larger validation cohort.",
    result_image=os.path.join(FIG, "FOREST_hcc_ICI_HSF2_pooled.png"),
)

# =====================================================================
# SLIDE 17: SUMMARY
# =====================================================================
add_overview_slide("Summary of Dry-Lab Findings", [
    "- Tested: HSF2 up -> NETosis-gene expression up (positively correlated) in fibrotic "
    "tissue. Result in 4 independent human liver/lung cohorts: HSF2 is NEGATIVELY correlated "
    "with the NETosis-core score (pooled rho=-0.31, p=0.010), replicated in 3/4 cohorts, and "
    "specific (survives the PTPRC immune-infiltration control).",
    "",
    "- No existing public ChIP-seq/co-expression database shows HSF2 activating these genes "
    "- genuinely unstudied territory.",
    "",
    "- In 3 independent human HCC immunotherapy cohorts, lower tumor HSF2 trends toward "
    "better treatment response (2/3 individually significant; pooled result inconclusive, "
    "needs more data).",
    "",
    "- Proposed reframing: HSF2 may not be the \"master switch\" that turns ON NETosis "
    "together with N2 polarization - it may instead \"decouple\" the two, acting as a brake "
    "specifically on the NETosis arm while the broader N2/immunosuppressive program proceeds.",
])

# =====================================================================
# SLIDE 18: ASK
# =====================================================================
add_overview_slide("What Would Help Next: The In Vivo RNA-seq Gene List", [
    "- The first lab experiment (PHMG 6 mg/kg in vivo -> neutrophil RNA-seq -> HSF2 ranked "
    "#1 upstream TF of the upregulated genes) is the missing piece that could directly test "
    "the \"decoupling\" idea above.",
    "",
    "- Request: the list of genes UPREGULATED in that in vivo experiment (or the gene set "
    "fed into the TF-enrichment analysis).",
    "",
    "- If PADI4/ELANE/MPO/CAMP/DEFA4 were part of that upregulated set -> HSF2 and NETosis "
    "genes moved together in vivo -> tension with the human tissue finding, needs "
    "reconciling.",
    "",
    "- If those genes were NOT in the upregulated set (flat or down) -> directly SUPPORTS "
    "the decoupling hypothesis using the lab's own mouse data, not just outside public data.",
])

# =====================================================================
# SLIDE 19: NEXT WEEK'S WET-LAB SUGGESTION
# =====================================================================
add_overview_slide("Suggestion for Next Week's Neutrophil Time-Course Experiment", [
    "- Planned: PHMG dose/time-course in isolated neutrophils (building on the single "
    "3 ug/mL, 6h Western blot result).",
    "",
    "- Suggested addition: full time course (1h/2h/4h/6h), not a single timepoint, tracking "
    "BOTH (a) HSF2 protein/mRNA and (b) NETosis-core mRNA (PADI4, ELANE, MPO, CAMP, DEFA4 "
    "by qPCR), alongside standard N1 (iNOS, TNF-a, ICAM-1) and N2 (Arg-1, CD206, IL-10) "
    "markers, plus one functional NETosis readout (extracellular DNA/SYTOX assay).",
    "",
    "- Prediction from dry-lab data: as HSF2 rises, PADI4/ELANE/MPO/CAMP/DEFA4 will NOT "
    "rise in parallel, while Arg-1/CD206 rise together with HSF2 - N2 polarization and "
    "NETosis-gene induction become decoupled under toxicant stress.",
    "",
    "- Either outcome (confirmed or refuted) is a real, reportable finding.",
])

prs.save(OUT)
print(f"Presentation build complete: {OUT}")
print(f"Total slides: {len(prs.slides)}")
