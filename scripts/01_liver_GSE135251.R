# Liver cohort 1 (PRIMARY, pre-registered as primary due to largest n and continuous
# fibrosis staging): GSE135251 (Govaere et al.), human NAFLD spectrum, RNA-seq, F0-F4.
# Raw per-sample Ensembl gene-level counts already on disk from prior project work;
# re-processed from scratch here (the previously saved masld_analysis.RData segfaults
# on load under the currently installed DESeq2 - version-mismatched serialized S4
# object - so this pipeline does NOT depend on that file).

suppressPackageStartupMessages({
  library(DESeq2)
  library(org.Hs.eg.db)
  library(AnnotationDbi)
  library(ggplot2)
})

source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")

RAW_DIR <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE135251_RAW"
SM_GZ   <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE135251_series_matrix.txt.gz"
OUT_DIR <- "C:/Users/SAMSUNG/Desktop/project2/results"
FIG_DIR <- "C:/Users/SAMSUNG/Desktop/project2/figures"

## ---- 1. Parse series matrix for sample metadata ---------------------------
sm <- readLines(gzfile(SM_GZ))
get_row <- function(tag) {
  ln <- grep(paste0("^", tag), sm, value = TRUE)[1]
  parts <- strsplit(ln, "\t")[[1]][-1]
  gsub('^"|"$', "", parts)
}
gsm    <- get_row("!Sample_geo_accession")
chars  <- sm[grep("^!Sample_characteristics_ch1", sm)]
parse_char <- function(line) {
  parts <- strsplit(line, "\t")[[1]][-1]
  gsub('^"|"$', "", parts)
}
nas_raw   <- parse_char(chars[1])
fib_raw   <- parse_char(chars[2])
group_raw <- parse_char(chars[3])
dis_raw   <- parse_char(chars[4])
stage_raw <- parse_char(chars[5])

meta <- data.frame(
  gsm             = gsm,
  nas_score       = as.numeric(sub("nas score: ", "", nas_raw)),
  fibrosis_stage  = as.numeric(sub("fibrosis stage: ", "", fib_raw)),
  group_in_paper  = sub("group in paper: ", "", group_raw),
  disease         = sub("disease: ", "", dis_raw),
  severity_stage  = sub("Stage: ", "", stage_raw),
  stringsAsFactors = FALSE
)
stopifnot(nrow(meta) == 216, !any(is.na(meta$fibrosis_stage)))

## ---- 2. Build count matrix from raw per-sample files -----------------------
files <- list.files(RAW_DIR, pattern = "\\.counts\\.txt$", full.names = TRUE)
file_gsm <- sub("_.*$", "", basename(files))
stopifnot(all(meta$gsm %in% file_gsm))
files <- files[match(meta$gsm, file_gsm)]   # align file order to meta row order exactly

first <- read.table(files[1], header = FALSE, sep = "\t", stringsAsFactors = FALSE)
gene_ids <- first[[1]]
counts <- matrix(NA_integer_, nrow = length(gene_ids), ncol = nrow(meta),
                  dimnames = list(gene_ids, meta$gsm))
for (i in seq_along(files)) {
  d <- read.table(files[i], header = FALSE, sep = "\t", stringsAsFactors = FALSE)
  stopifnot(identical(d[[1]], gene_ids))    # guard against row-order mismatch across files
  counts[, i] <- d[[2]]
}
# drop HTSeq summary lines if present (e.g. __no_feature) - Ensembl IDs only
counts <- counts[grepl("^ENSG", rownames(counts)), ]

## ---- 4a. Resolve gene panel symbol -> Ensembl BEFORE filtering --------------
# Neutrophil granule/NETosis genes are expected to be lowly expressed in bulk
# liver tissue (neutrophils are a minor fraction of the cell mixture) - this is
# real biology, not a QC failure. Pre-specified panel genes are therefore
# force-retained through the low-count filter (union, not replacement), and
# their per-sample detection rate is reported as a transparency/limitation
# metric rather than silently dropping them.
panel_all <- unique(c(TARGET_TF, NET_EXTENDED))
sym2ens_raw <- AnnotationDbi::select(org.Hs.eg.db, keys = panel_all,
                                      keytype = "SYMBOL", columns = "ENSEMBL")
sym2ens_raw <- sym2ens_raw[!is.na(sym2ens_raw$ENSEMBL) & sym2ens_raw$ENSEMBL %in% rownames(counts), ]
# collapse 1:many SYMBOL->ENSEMBL mappings by picking the Ensembl ID with the
# highest total counts across samples (the biologically "real" annotated locus
# in this count-file build; alternate IDs were all-zero pseudo/readthrough entries)
tot <- rowSums(counts[sym2ens_raw$ENSEMBL, , drop = FALSE])
sym2ens_raw$total_count <- tot
sym2ens <- do.call(rbind, lapply(split(sym2ens_raw, sym2ens_raw$SYMBOL), function(d) d[which.max(d$total_count), ]))
cat("Panel gene -> Ensembl mapping (1:many resolved by max total count):\n"); print(sym2ens)

detection_rate <- setNames(rowMeans(counts[sym2ens$ENSEMBL, , drop = FALSE] > 0), sym2ens$SYMBOL)
cat("\nPer-sample detection rate (fraction of 216 samples with count > 0):\n")
print(round(sort(detection_rate), 3))
write.csv(data.frame(gene = names(detection_rate), detection_rate = detection_rate),
          file.path(OUT_DIR, "liver_GSE135251_gene_detection_rate.csv"), row.names = FALSE)

missing_genes <- setdiff(panel_all, sym2ens$SYMBOL)
if (length(missing_genes) > 0) cat("\nNOTE - panel genes with no Ensembl match in this count build:",
                                    paste(missing_genes, collapse = ", "), "\n")

## ---- 3. DESeq2 size-factor normalization + variance-stabilizing transform --
keep <- (rowMeans(counts) >= 10) | (rownames(counts) %in% sym2ens$ENSEMBL)
counts_f <- counts[keep, ]
dds <- DESeqDataSetFromMatrix(countData = counts_f,
                               colData   = meta,
                               design    = ~1)
dds <- estimateSizeFactors(dds)
vsd <- vst(dds, blind = TRUE)          # blind=TRUE: no design-driven shrinkage, appropriate for a correlation study
expr <- assay(vsd)

## ---- 4b. Extract panel expression -------------------------------------------
expr_panel <- expr[sym2ens$ENSEMBL, , drop = FALSE]
rownames(expr_panel) <- sym2ens$SYMBOL[match(rownames(expr_panel), sym2ens$ENSEMBL)]

## ---- 5. Derived variables ---------------------------------------------------
hsf2 <- as.numeric(expr_panel[TARGET_TF, ])
net_core_present <- intersect(NET_CORE, rownames(expr_panel))
net_ext_present  <- intersect(NET_EXTENDED, rownames(expr_panel))
net_core_score <- panel_score(expr_panel, NET_CORE, min_genes = 2)
net_ext_score  <- panel_score(expr_panel, NET_EXTENDED, min_genes = 4)

df <- data.frame(
  gsm = meta$gsm, fibrosis_stage = meta$fibrosis_stage, disease = meta$disease,
  nas_score = meta$nas_score,
  HSF2 = hsf2, NET_core = net_core_score, NET_ext = net_ext_score
)
df_nafld <- df[df$disease == "NAFLD", ]   # diseased/fibrotic subset - pre-specified primary population

## ---- 6. Pre-specified primary + secondary tests ------------------------------
results <- list()

# Primary endpoint: HSF2 vs NET_core score, within NAFLD (fibrotic) samples
results$primary <- spearman_report(df_nafld$HSF2, df_nafld$NET_core,
                                    "GSE135251_liver: HSF2 vs NET_core (NAFLD subset, primary)")

# Secondary/robustness
results$primary_all <- spearman_report(df$HSF2, df$NET_core,
                                        "GSE135251_liver: HSF2 vs NET_core (all samples incl. control)")
results$extended <- spearman_report(df_nafld$HSF2, df_nafld$NET_ext,
                                     "GSE135251_liver: HSF2 vs NET_extended (NAFLD subset)")
results$hsf2_vs_stage <- spearman_report(df$HSF2, df$fibrosis_stage,
                                          "GSE135251_liver: HSF2 vs fibrosis stage (ordinal, all samples)")
results$netcore_vs_stage <- spearman_report(df$NET_core, df$fibrosis_stage,
                                             "GSE135251_liver: NET_core vs fibrosis stage (ordinal, all samples)")

# Exploratory: HSF2 vs each individual panel gene (NAFLD subset) - BH-FDR across these
indiv <- lapply(setdiff(net_ext_present, TARGET_TF), function(g) {
  spearman_report(df_nafld$HSF2, as.numeric(expr_panel[g, meta$disease == "NAFLD"]),
                   paste0("GSE135251_liver: HSF2 vs ", g, " (NAFLD subset)"))
})
indiv_df <- do.call(rbind, indiv)
indiv_df$p_FDR <- p.adjust(indiv_df$p_value, method = "BH")

summary_df <- do.call(rbind, results)
write.csv(summary_df, file.path(OUT_DIR, "liver_GSE135251_primary_results.csv"), row.names = FALSE)
write.csv(indiv_df,   file.path(OUT_DIR, "liver_GSE135251_individual_gene_results.csv"), row.names = FALSE)
write.csv(df,         file.path(OUT_DIR, "liver_GSE135251_sample_level_data.csv"), row.names = FALSE)

cat("\n=== PRIMARY + SECONDARY RESULTS (GSE135251 liver) ===\n")
print(summary_df, row.names = FALSE)
cat("\n=== INDIVIDUAL GENE RESULTS (BH-FDR corrected) ===\n")
print(indiv_df[order(indiv_df$p_FDR), c("comparison", "n", "rho", "p_value", "p_FDR")], row.names = FALSE)

## ---- 7. Figures --------------------------------------------------------------
p1 <- ggplot(df_nafld, aes(x = HSF2, y = NET_core)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = TRUE, color = "firebrick") +
  labs(title = "GSE135251 (liver, NAFLD subset, n=206)",
       subtitle = sprintf("Spearman rho = %.2f, 95%% CI [%.2f, %.2f], p = %.2g",
                           results$primary$rho, results$primary$ci_lo,
                           results$primary$ci_hi, results$primary$p_value),
       x = "HSF2 (VST-normalized expression)", y = "NET_core score (z-mean: PADI4/ELANE/MPO)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "liver_GSE135251_HSF2_vs_NETcore.png"), p1, width = 6, height = 5, dpi = 300)

df$fibrosis_stage_f <- factor(df$fibrosis_stage, levels = 0:4)
p2 <- ggplot(df, aes(x = fibrosis_stage_f, y = HSF2)) +
  geom_boxplot(outlier.shape = NA) + geom_jitter(width = 0.15, alpha = 0.4) +
  labs(title = "GSE135251 (liver): HSF2 across fibrosis stage",
       x = "Fibrosis stage (0=none, 4=cirrhosis)", y = "HSF2 (VST)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "liver_GSE135251_HSF2_by_stage.png"), p2, width = 6, height = 5, dpi = 300)

saveRDS(list(df = df, expr_panel = expr_panel, results = results, indiv_df = indiv_df),
        file.path(OUT_DIR, "liver_GSE135251_full_output.rds"))

cat("\nDone. Outputs written to", OUT_DIR, "and", FIG_DIR, "\n")
