# Cross-organ, cross-platform synthesis of the pre-specified primary endpoint
# (HSF2 vs NET_core score, Spearman rho, within diseased/fibrotic tissue) across
# all 4 independent cohorts, using a from-scratch Fisher-z DerSimonian-Laird
# random-effects meta-analysis (see 00_functions.R::meta_cor_DL).

suppressPackageStartupMessages(library(ggplot2))
source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")

OUT_DIR <- "C:/Users/SAMSUNG/Desktop/project2/results"
FIG_DIR <- "C:/Users/SAMSUNG/Desktop/project2/figures"

files <- c(
  liver_GSE135251 = "liver_GSE135251_primary_results.csv",
  liver_GSE14323  = "liver_GSE14323_primary_results.csv",
  lung_GSE47460   = "lung_GSE47460_primary_results.csv",
  lung_GSE53845   = "lung_GSE53845_primary_results.csv"
)
primary_rows <- lapply(names(files), function(nm) {
  d <- read.csv(file.path(OUT_DIR, files[nm]))
  row <- d[grepl("primary", d$comparison), ][1, ]
  row$cohort <- nm
  row$organ  <- ifelse(grepl("liver", nm), "Liver", "Lung")
  row
})
primary_df <- do.call(rbind, primary_rows)
primary_df <- primary_df[, c("cohort", "organ", "comparison", "n", "rho", "p_value", "ci_lo", "ci_hi")]
write.csv(primary_df, file.path(OUT_DIR, "ALL_COHORTS_primary_endpoint_summary.csv"), row.names = FALSE)
cat("=== Primary endpoint (HSF2 vs NET_core) across all 4 cohorts ===\n")
print(primary_df, row.names = FALSE)

## ---- Overall meta-analysis (all 4 cohorts) -------------------------------------
meta_all <- meta_cor_DL(primary_df$rho, primary_df$n, primary_df$cohort)
cat(sprintf("\n=== Overall random-effects meta-analysis (4 cohorts, 2 organs) ===\npooled rho = %.3f, 95%% CI [%.3f, %.3f], p = %.3g\nHeterogeneity: Q(df=%d) = %.2f, I^2 = %.1f%%, tau^2 = %.4f\n",
            meta_all$pooled_rho, meta_all$ci_lo, meta_all$ci_hi, meta_all$p_value,
            meta_all$df, meta_all$Q, meta_all$I2, meta_all$tau2))
print(meta_all$per_study)

## ---- Per-organ meta-analysis (liver-only, lung-only) ---------------------------
liver_df <- primary_df[primary_df$organ == "Liver", ]
lung_df  <- primary_df[primary_df$organ == "Lung", ]
meta_liver <- meta_cor_DL(liver_df$rho, liver_df$n, liver_df$cohort)
meta_lung  <- meta_cor_DL(lung_df$rho,  lung_df$n,  lung_df$cohort)
cat(sprintf("\nLiver-only pooled rho = %.3f, 95%% CI [%.3f, %.3f], p = %.3g\n",
            meta_liver$pooled_rho, meta_liver$ci_lo, meta_liver$ci_hi, meta_liver$p_value))
cat(sprintf("Lung-only  pooled rho = %.3f, 95%% CI [%.3f, %.3f], p = %.3g\n",
            meta_lung$pooled_rho, meta_lung$ci_lo, meta_lung$ci_hi, meta_lung$p_value))

meta_summary <- data.frame(
  level = c("Overall (4 cohorts)", "Liver only (2 cohorts)", "Lung only (2 cohorts)"),
  pooled_rho = c(meta_all$pooled_rho, meta_liver$pooled_rho, meta_lung$pooled_rho),
  ci_lo = c(meta_all$ci_lo, meta_liver$ci_lo, meta_lung$ci_lo),
  ci_hi = c(meta_all$ci_hi, meta_liver$ci_hi, meta_lung$ci_hi),
  p_value = c(meta_all$p_value, meta_liver$p_value, meta_lung$p_value),
  I2 = c(meta_all$I2, meta_liver$I2, meta_lung$I2)
)
write.csv(meta_summary, file.path(OUT_DIR, "ALL_COHORTS_meta_analysis_summary.csv"), row.names = FALSE)
cat("\n=== Meta-analysis summary table ===\n"); print(meta_summary, row.names = FALSE)

## ---- Forest plot ----------------------------------------------------------------
forest_df <- rbind(
  data.frame(label = primary_df$cohort, rho = primary_df$rho,
             ci_lo = primary_df$ci_lo, ci_hi = primary_df$ci_hi,
             n = primary_df$n, type = "cohort"),
  data.frame(label = "Liver pooled (RE)", rho = meta_liver$pooled_rho,
             ci_lo = meta_liver$ci_lo, ci_hi = meta_liver$ci_hi, n = sum(liver_df$n), type = "pooled"),
  data.frame(label = "Lung pooled (RE)", rho = meta_lung$pooled_rho,
             ci_lo = meta_lung$ci_lo, ci_hi = meta_lung$ci_hi, n = sum(lung_df$n), type = "pooled"),
  data.frame(label = "Overall pooled (RE)", rho = meta_all$pooled_rho,
             ci_lo = meta_all$ci_lo, ci_hi = meta_all$ci_hi, n = sum(primary_df$n), type = "pooled")
)
forest_df$label <- factor(forest_df$label, levels = rev(forest_df$label))

p <- ggplot(forest_df, aes(x = rho, y = label, color = type)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.2) +
  geom_point(aes(size = n)) +
  scale_color_manual(values = c(cohort = "steelblue", pooled = "firebrick")) +
  labs(title = "HSF2 vs NETosis-core gene score (PADI4/ELANE/MPO) in fibrotic tissue",
       subtitle = "Spearman rho, 95% bootstrap/RE-meta CI, pre-specified primary endpoint per cohort",
       x = "Spearman rho (HSF2 vs NET_core)", y = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave(file.path(FIG_DIR, "FOREST_HSF2_vs_NETcore_all_cohorts.png"), p, width = 8, height = 5, dpi = 300)

cat("\nDone. Meta-analysis outputs written to", OUT_DIR, "and", FIG_DIR, "\n")
