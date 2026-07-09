# Lung cohort 2 (REPLICATION, independent submission from GSE47460 though same array
# family/GPL6480): GSE53845, two-color Agilent, Cy5 sample vs common Stratagene
# Universal Human Reference RNA (Cy3) - exprs() values are log2(sample/reference)
# ratios, not absolute intensities (range approx -8 to +11, centered near 0). This is
# fine for a within-cohort correlation analysis (relative expression), but is a
# different normalization scale than GSE47460's cyclic-loess single-channel intensities
# - correlation coefficients (scale-free, rank-based/Spearman) are still comparable
# across cohorts; raw expression values are not.
# Pre-specified replication rule: a GSE47460 (cohort 1, lung) finding counts as
# REPLICATED only if this cohort agrees in sign AND is nominally significant (p<0.05).

suppressPackageStartupMessages({
  library(GEOquery)
  library(Biobase)
  library(ggplot2)
})
source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")

DATA_DIR <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE53845"
OUT_DIR  <- "C:/Users/SAMSUNG/Desktop/project2/results"
FIG_DIR  <- "C:/Users/SAMSUNG/Desktop/project2/figures"

gset <- getGEO("GSE53845", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
es <- gset[[1]]
stopifnot(ncol(es) == 48)

expr <- exprs(es)
fd   <- fData(es)
diagnosis <- pData(es)$`diagnosis:ch1`  # "control" / "IPF"

## ---- Resolve gene panel probe -> symbol (collapse multi-probe by max mean expr) --
panel_all <- unique(c(TARGET_TF, NET_EXTENDED))
hits <- fd[fd$`Gene symbol` %in% panel_all, c("ID", "Gene symbol")]
hits$mean_expr <- rowMeans(expr[hits$ID, , drop = FALSE], na.rm = TRUE)
sym2probe <- do.call(rbind, lapply(split(hits, hits$`Gene symbol`), function(d) d[which.max(d$mean_expr), ]))
cat("Panel gene -> probe mapping (multi-probe collapsed by max mean expression):\n")
print(sym2probe[, c("Gene symbol", "ID", "mean_expr")])
missing_genes <- setdiff(panel_all, sym2probe$`Gene symbol`)
if (length(missing_genes) > 0) cat("\nNOTE - panel genes with no probe on GPL6480 (this series):",
                                    paste(missing_genes, collapse = ", "), "\n")

expr_panel <- expr[sym2probe$ID, , drop = FALSE]
rownames(expr_panel) <- sym2probe$`Gene symbol`

## ---- Derived variables --------------------------------------------------------
hsf2 <- as.numeric(expr_panel[TARGET_TF, ])
net_core_score <- panel_score(expr_panel, NET_CORE, min_genes = 2)
net_ext_score  <- panel_score(expr_panel, NET_EXTENDED, min_genes = 4)

df <- data.frame(gsm = colnames(es), diagnosis = diagnosis,
                  HSF2 = hsf2, NET_core = net_core_score, NET_ext = net_ext_score)
df_ipf <- df[df$diagnosis == "IPF", ]     # primary/replication population, n=40
df$severity <- ifelse(df$diagnosis == "IPF", 1, 0)

## ---- Pre-specified primary + secondary tests ----------------------------------
results <- list()
results$primary <- spearman_report(df_ipf$HSF2, df_ipf$NET_core,
                                    "GSE53845_lung: HSF2 vs NET_core (IPF subset, primary/replication)")
results$primary_all <- spearman_report(df$HSF2, df$NET_core,
                                        "GSE53845_lung: HSF2 vs NET_core (all samples incl. control)")
results$extended <- spearman_report(df_ipf$HSF2, df_ipf$NET_ext,
                                     "GSE53845_lung: HSF2 vs NET_extended (IPF subset)")
results$hsf2_vs_severity <- spearman_report(df$HSF2, df$severity,
                                             "GSE53845_lung: HSF2 vs disease status (binary control/IPF)")
results$netcore_vs_severity <- spearman_report(df$NET_core, df$severity,
                                                "GSE53845_lung: NET_core vs disease status (binary control/IPF)")

net_ext_present <- intersect(NET_EXTENDED, rownames(expr_panel))
indiv <- lapply(net_ext_present, function(g) {
  spearman_report(df_ipf$HSF2, as.numeric(expr_panel[g, df$diagnosis == "IPF"]),
                   paste0("GSE53845_lung: HSF2 vs ", g, " (IPF subset)"))
})
indiv_df <- do.call(rbind, indiv)
indiv_df$p_FDR <- p.adjust(indiv_df$p_value, method = "BH")

summary_df <- do.call(rbind, results)
write.csv(summary_df, file.path(OUT_DIR, "lung_GSE53845_primary_results.csv"), row.names = FALSE)
write.csv(indiv_df,   file.path(OUT_DIR, "lung_GSE53845_individual_gene_results.csv"), row.names = FALSE)
write.csv(df,         file.path(OUT_DIR, "lung_GSE53845_sample_level_data.csv"), row.names = FALSE)

cat("\n=== PRIMARY + SECONDARY RESULTS (GSE53845 lung, replication cohort) ===\n")
print(summary_df, row.names = FALSE)
cat("\n=== INDIVIDUAL GENE RESULTS (BH-FDR corrected) ===\n")
print(indiv_df[order(indiv_df$p_FDR), c("comparison", "n", "rho", "p_value", "p_FDR")], row.names = FALSE)

## ---- Replication verdict vs cohort 1 (GSE47460) --------------------------------
c1 <- read.csv(file.path(OUT_DIR, "lung_GSE47460_primary_results.csv"))
c1_primary <- c1[c1$comparison == "GSE47460_lung: HSF2 vs NET_core (UIP/IPF subset, primary)", ]
same_sign <- sign(c1_primary$rho) == sign(results$primary$rho)
both_sig  <- c1_primary$p_value < 0.05 & results$primary$p_value < 0.05
cat(sprintf("\n=== REPLICATION CHECK: HSF2 vs NET_core primary endpoint (lung) ===\nCohort1 (GSE47460) rho=%.3f p=%.3g | Cohort2 (GSE53845) rho=%.3f p=%.3g\nSame sign: %s | Both nominally significant: %s | REPLICATED (pre-specified rule): %s\n",
            c1_primary$rho, c1_primary$p_value, results$primary$rho, results$primary$p_value,
            same_sign, both_sig, same_sign && both_sig))

## ---- Figures --------------------------------------------------------------------
p1 <- ggplot(df_ipf, aes(x = HSF2, y = NET_core)) +
  geom_point(alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE, color = "firebrick") +
  labs(title = "GSE53845 (lung, IPF subset, n=40)",
       subtitle = sprintf("Spearman rho = %.2f, 95%% CI [%.2f, %.2f], p = %.2g",
                           results$primary$rho, results$primary$ci_lo,
                           results$primary$ci_hi, results$primary$p_value),
       x = "HSF2 (log2 ratio vs reference)", y = "NET_core score (z-mean: PADI4/ELANE/MPO)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "lung_GSE53845_HSF2_vs_NETcore.png"), p1, width = 6.5, height = 5, dpi = 300)

df$diagnosis_f <- factor(df$diagnosis, levels = c("control", "IPF"))
p2 <- ggplot(df, aes(x = diagnosis_f, y = HSF2)) +
  geom_boxplot(outlier.shape = NA) + geom_jitter(width = 0.15, alpha = 0.4) +
  labs(title = "GSE53845 (lung): HSF2, control vs IPF", x = NULL, y = "HSF2 (log2 ratio)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "lung_GSE53845_HSF2_by_group.png"), p2, width = 6, height = 5, dpi = 300)

saveRDS(list(df = df, expr_panel = expr_panel, results = results, indiv_df = indiv_df),
        file.path(OUT_DIR, "lung_GSE53845_full_output.rds"))

cat("\nDone. Outputs written to", OUT_DIR, "and", FIG_DIR, "\n")
