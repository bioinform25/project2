# Liver cohort 2 (REPLICATION, independent platform: Affymetrix HG-U133A/GPL571,
# RMA-normalized log2 values). Normal / cirrhosis / cirrhosisHCC / HCC liver tissue
# (Wurmbach et al. design). Only the GPL571 sub-series (n=115, has Normal+disease
# groups) is used; the GPL96 sub-series (n=9, HCC-only, no comparator) is dropped.
#
# Pre-specified replication rule (set before viewing this cohort's results):
# a GSE135251 (cohort 1) finding counts as REPLICATED only if this cohort agrees
# in sign AND is nominally significant (p < 0.05).
# Disease severity is coded ordinally as Normal=0 < cirrhosis=1 < cirrhosisHCC=2 <
# HCC=3 (progression proxy); this ordering is a modeling assumption, not a
# validated continuous staging scale like GSE135251's fibrosis stage - noted as
# a limitation, not treated as equivalent evidence.

suppressPackageStartupMessages({
  library(GEOquery)
  library(Biobase)
  library(ggplot2)
})
source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")

DATA_DIR <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE14323"
OUT_DIR  <- "C:/Users/SAMSUNG/Desktop/project2/results"
FIG_DIR  <- "C:/Users/SAMSUNG/Desktop/project2/figures"

gset <- getGEO("GSE14323", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
es <- gset[[1]]           # GPL571, n=115, has Normal/cirrhosis/cirrhosisHCC/HCC
stopifnot(annotation(es) == "GPL571", ncol(es) == 115)

expr <- exprs(es)          # already RMA log2-normalized (range check: 3.5-14.4)
fd   <- fData(es)
tissue <- pData(es)$`Tissue:ch1`
sev_map <- c(Normal = 0, cirrhosis = 1, cirrhosisHCC = 2, HCC = 3)
severity <- unname(sev_map[tissue])
stopifnot(!any(is.na(severity)))

## ---- Resolve gene panel probe -> symbol (collapse multi-probe by max mean expr) --
panel_all <- unique(c(TARGET_TF, NET_EXTENDED))
hits <- fd[fd$`Gene symbol` %in% panel_all, c("ID", "Gene symbol")]
hits$mean_expr <- rowMeans(expr[hits$ID, , drop = FALSE])
sym2probe <- do.call(rbind, lapply(split(hits, hits$`Gene symbol`), function(d) d[which.max(d$mean_expr), ]))
cat("Panel gene -> probe mapping (multi-probe collapsed by max mean expression):\n")
print(sym2probe[, c("Gene symbol", "ID", "mean_expr")])

missing_genes <- setdiff(panel_all, sym2probe$`Gene symbol`)
if (length(missing_genes) > 0) cat("\nNOTE - panel genes with no probe on GPL571:",
                                    paste(missing_genes, collapse = ", "), "\n")

expr_panel <- expr[sym2probe$ID, , drop = FALSE]
rownames(expr_panel) <- sym2probe$`Gene symbol`

## ---- Derived variables --------------------------------------------------------
hsf2 <- as.numeric(expr_panel[TARGET_TF, ])
net_core_score <- panel_score(expr_panel, NET_CORE, min_genes = 2)
net_ext_score  <- panel_score(expr_panel, NET_EXTENDED, min_genes = 4)

df <- data.frame(gsm = colnames(es), tissue = tissue, severity = severity,
                  HSF2 = hsf2, NET_core = net_core_score, NET_ext = net_ext_score)
df_disease <- df[df$tissue != "Normal", ]   # diseased subset - analogous primary population to cohort 1

## ---- Pre-specified primary + secondary tests ----------------------------------
results <- list()
results$primary <- spearman_report(df_disease$HSF2, df_disease$NET_core,
                                    "GSE14323_liver: HSF2 vs NET_core (diseased subset, primary/replication)")
results$primary_all <- spearman_report(df$HSF2, df$NET_core,
                                        "GSE14323_liver: HSF2 vs NET_core (all samples incl. normal)")
results$extended <- spearman_report(df_disease$HSF2, df_disease$NET_ext,
                                     "GSE14323_liver: HSF2 vs NET_extended (diseased subset)")
results$hsf2_vs_severity <- spearman_report(df$HSF2, df$severity,
                                             "GSE14323_liver: HSF2 vs disease severity (ordinal, all samples)")
results$netcore_vs_severity <- spearman_report(df$NET_core, df$severity,
                                                "GSE14323_liver: NET_core vs disease severity (ordinal, all samples)")

net_ext_present <- intersect(NET_EXTENDED, rownames(expr_panel))
indiv <- lapply(net_ext_present, function(g) {
  spearman_report(df_disease$HSF2, as.numeric(expr_panel[g, df$tissue != "Normal"]),
                   paste0("GSE14323_liver: HSF2 vs ", g, " (diseased subset)"))
})
indiv_df <- do.call(rbind, indiv)
indiv_df$p_FDR <- p.adjust(indiv_df$p_value, method = "BH")

summary_df <- do.call(rbind, results)
write.csv(summary_df, file.path(OUT_DIR, "liver_GSE14323_primary_results.csv"), row.names = FALSE)
write.csv(indiv_df,   file.path(OUT_DIR, "liver_GSE14323_individual_gene_results.csv"), row.names = FALSE)
write.csv(df,         file.path(OUT_DIR, "liver_GSE14323_sample_level_data.csv"), row.names = FALSE)

cat("\n=== PRIMARY + SECONDARY RESULTS (GSE14323 liver, replication cohort) ===\n")
print(summary_df, row.names = FALSE)
cat("\n=== INDIVIDUAL GENE RESULTS (BH-FDR corrected) ===\n")
print(indiv_df[order(indiv_df$p_FDR), c("comparison", "n", "rho", "p_value", "p_FDR")], row.names = FALSE)

## ---- Replication verdict vs cohort 1 (GSE135251) -------------------------------
c1 <- read.csv(file.path(OUT_DIR, "liver_GSE135251_primary_results.csv"))
c1_primary <- c1[c1$comparison == "GSE135251_liver: HSF2 vs NET_core (NAFLD subset, primary)", ]
same_sign <- sign(c1_primary$rho) == sign(results$primary$rho)
both_sig  <- c1_primary$p_value < 0.05 & results$primary$p_value < 0.05
cat(sprintf("\n=== REPLICATION CHECK: HSF2 vs NET_core primary endpoint ===\nCohort1 (GSE135251) rho=%.3f p=%.3g | Cohort2 (GSE14323) rho=%.3f p=%.3g\nSame sign: %s | Both nominally significant: %s | REPLICATED (pre-specified rule): %s\n",
            c1_primary$rho, c1_primary$p_value, results$primary$rho, results$primary$p_value,
            same_sign, both_sig, same_sign && both_sig))

## ---- Figures --------------------------------------------------------------------
p1 <- ggplot(df_disease, aes(x = HSF2, y = NET_core)) +
  geom_point(aes(color = tissue), alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE, color = "firebrick") +
  labs(title = "GSE14323 (liver, diseased subset, n=96)",
       subtitle = sprintf("Spearman rho = %.2f, 95%% CI [%.2f, %.2f], p = %.2g",
                           results$primary$rho, results$primary$ci_lo,
                           results$primary$ci_hi, results$primary$p_value),
       x = "HSF2 (RMA log2 expression)", y = "NET_core score (z-mean: PADI4/ELANE/MPO)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "liver_GSE14323_HSF2_vs_NETcore.png"), p1, width = 6.5, height = 5, dpi = 300)

df$tissue_f <- factor(df$tissue, levels = c("Normal", "cirrhosis", "cirrhosisHCC", "HCC"))
p2 <- ggplot(df, aes(x = tissue_f, y = HSF2)) +
  geom_boxplot(outlier.shape = NA) + geom_jitter(width = 0.15, alpha = 0.4) +
  labs(title = "GSE14323 (liver): HSF2 across disease groups", x = NULL, y = "HSF2 (RMA log2)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "liver_GSE14323_HSF2_by_group.png"), p2, width = 6, height = 5, dpi = 300)

saveRDS(list(df = df, expr_panel = expr_panel, results = results, indiv_df = indiv_df),
        file.path(OUT_DIR, "liver_GSE14323_full_output.rds"))

cat("\nDone. Outputs written to", OUT_DIR, "and", FIG_DIR, "\n")
