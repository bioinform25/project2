# Lung cohort 1 (PRIMARY, largest n): GSE47460 (Lung Tissue Research Consortium /
# Lung Genomics Research Consortium), Agilent GPL14550 sub-series (n=429; probes
# already collapsed to 1 gene/1 probe by the submitters via highest signal intensity,
# cyclic-loess normalized). Control vs COPD vs ILD, with ILD subtyped; "2-UIP/IPF" is
# the histologically fibrotic subtype and is the population used for "fibrotic subset"
# analyses, analogous to the diseased/fibrotic subsets used in the liver cohorts.
# No continuous fibrosis-stage grade is available for this cohort (unlike GSE135251's
# F0-F4), so disease status is coded as a binary severity variable (Control=0, UIP/IPF=1)
# - noted as a design difference/limitation vs. the liver ordinal analyses.

suppressPackageStartupMessages({
  library(GEOquery)
  library(Biobase)
  library(ggplot2)
})
source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")

DATA_DIR <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE47460"
OUT_DIR  <- "C:/Users/SAMSUNG/Desktop/project2/results"
FIG_DIR  <- "C:/Users/SAMSUNG/Desktop/project2/figures"

gset <- getGEO("GSE47460", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
es <- gset[[1]]  # GPL14550, n=429
stopifnot(annotation(es) == "GPL14550", ncol(es) == 429)

expr <- exprs(es)
fd   <- fData(es)
pd   <- pData(es)

disease_state <- pd$`disease state:ch1`
ild_subtype   <- pd$`ild subtype:ch1`
is_ipf   <- !is.na(ild_subtype) & grepl("UIP/IPF", ild_subtype)
is_ctrl  <- disease_state == "Control"
is_copd  <- disease_state == "Chronic Obstructive Lung Disease"

group <- ifelse(is_ctrl, "Control", ifelse(is_ipf, "UIP_IPF",
                ifelse(is_copd, "COPD", ifelse(disease_state == "Interstitial lung disease", "ILD_other", NA))))
cat("Group sizes:\n"); print(table(group, useNA = "always"))

## ---- Map gene panel (already 1 probe/gene on this platform) ------------------
panel_all <- unique(c(TARGET_TF, NET_EXTENDED))
sym2probe <- fd[fd$GENE_SYMBOL %in% panel_all, c("ID", "GENE_SYMBOL")]
cat("\nPanel gene -> probe mapping:\n"); print(sym2probe)
missing_genes <- setdiff(panel_all, sym2probe$GENE_SYMBOL)
if (length(missing_genes) > 0) cat("\nNOTE - panel genes with no probe on GPL14550:",
                                    paste(missing_genes, collapse = ", "), "\n")

expr_panel <- expr[sym2probe$ID, , drop = FALSE]
rownames(expr_panel) <- sym2probe$GENE_SYMBOL

## ---- Derived variables --------------------------------------------------------
hsf2 <- as.numeric(expr_panel[TARGET_TF, ])
net_core_score <- panel_score(expr_panel, NET_CORE, min_genes = 2)
net_ext_score  <- panel_score(expr_panel, NET_EXTENDED, min_genes = 4)

df <- data.frame(gsm = colnames(es), group = group,
                  HSF2 = hsf2, NET_core = net_core_score, NET_ext = net_ext_score)
df_fibrotic <- df[!is.na(df$group) & df$group == "UIP_IPF", ]           # primary population
df_ctrl_ipf <- df[!is.na(df$group) & df$group %in% c("Control", "UIP_IPF"), ]
df_ctrl_ipf$severity <- ifelse(df_ctrl_ipf$group == "UIP_IPF", 1, 0)

## ---- Pre-specified primary + secondary tests ----------------------------------
results <- list()
results$primary <- spearman_report(df_fibrotic$HSF2, df_fibrotic$NET_core,
                                    "GSE47460_lung: HSF2 vs NET_core (UIP/IPF subset, primary)")
results$primary_all <- spearman_report(df_ctrl_ipf$HSF2, df_ctrl_ipf$NET_core,
                                        "GSE47460_lung: HSF2 vs NET_core (Control+IPF, all)")
results$extended <- spearman_report(df_fibrotic$HSF2, df_fibrotic$NET_ext,
                                     "GSE47460_lung: HSF2 vs NET_extended (UIP/IPF subset)")
results$hsf2_vs_severity <- spearman_report(df_ctrl_ipf$HSF2, df_ctrl_ipf$severity,
                                             "GSE47460_lung: HSF2 vs disease status (binary Control/IPF)")
results$netcore_vs_severity <- spearman_report(df_ctrl_ipf$NET_core, df_ctrl_ipf$severity,
                                                "GSE47460_lung: NET_core vs disease status (binary Control/IPF)")

net_ext_present <- intersect(NET_EXTENDED, rownames(expr_panel))
indiv <- lapply(net_ext_present, function(g) {
  spearman_report(df_fibrotic$HSF2, as.numeric(expr_panel[g, df$group == "UIP_IPF" & !is.na(df$group)]),
                   paste0("GSE47460_lung: HSF2 vs ", g, " (UIP/IPF subset)"))
})
indiv_df <- do.call(rbind, indiv)
indiv_df$p_FDR <- p.adjust(indiv_df$p_value, method = "BH")

summary_df <- do.call(rbind, results)
write.csv(summary_df, file.path(OUT_DIR, "lung_GSE47460_primary_results.csv"), row.names = FALSE)
write.csv(indiv_df,   file.path(OUT_DIR, "lung_GSE47460_individual_gene_results.csv"), row.names = FALSE)
write.csv(df,         file.path(OUT_DIR, "lung_GSE47460_sample_level_data.csv"), row.names = FALSE)

cat("\n=== PRIMARY + SECONDARY RESULTS (GSE47460 lung, primary cohort) ===\n")
print(summary_df, row.names = FALSE)
cat("\n=== INDIVIDUAL GENE RESULTS (BH-FDR corrected) ===\n")
print(indiv_df[order(indiv_df$p_FDR), c("comparison", "n", "rho", "p_value", "p_FDR")], row.names = FALSE)

## ---- Figures --------------------------------------------------------------------
p1 <- ggplot(df_fibrotic, aes(x = HSF2, y = NET_core)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = TRUE, color = "firebrick") +
  labs(title = sprintf("GSE47460 (lung, UIP/IPF subset, n=%d)", nrow(df_fibrotic)),
       subtitle = sprintf("Spearman rho = %.2f, 95%% CI [%.2f, %.2f], p = %.2g",
                           results$primary$rho, results$primary$ci_lo,
                           results$primary$ci_hi, results$primary$p_value),
       x = "HSF2 (Agilent log2 intensity)", y = "NET_core score (z-mean: PADI4/ELANE/MPO)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "lung_GSE47460_HSF2_vs_NETcore.png"), p1, width = 6.5, height = 5, dpi = 300)

df$group_f <- factor(df$group, levels = c("Control", "COPD", "ILD_other", "UIP_IPF"))
p2 <- ggplot(subset(df, !is.na(group_f)), aes(x = group_f, y = HSF2)) +
  geom_boxplot(outlier.shape = NA) + geom_jitter(width = 0.15, alpha = 0.3) +
  labs(title = "GSE47460 (lung): HSF2 across disease groups", x = NULL, y = "HSF2 (log2 intensity)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "lung_GSE47460_HSF2_by_group.png"), p2, width = 6.5, height = 5, dpi = 300)

saveRDS(list(df = df, expr_panel = expr_panel, results = results, indiv_df = indiv_df),
        file.path(OUT_DIR, "lung_GSE47460_full_output.rds"))

cat("\nDone. Outputs written to", OUT_DIR, "and", FIG_DIR, "\n")
