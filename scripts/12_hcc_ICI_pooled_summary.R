# Pool the 3 independent HCC-ICI cohorts (GSE215011 nivolumab monotherapy,
# GSE279750 anti-PD-L1 combo, GSE235863 anti-PD-1+lenvatinib combo) for the
# HSF2: Responder-vs-Non-responder comparison, using rank-biserial correlation
# (scale-free Wilcoxon effect size, valid across cohorts measured on different
# expression scales/normalizations) combined via the same from-scratch Fisher-z
# DerSimonian-Laird random-effects meta-analysis used for the fibrosis cohorts.
#
# IMPORTANT DESIGN HETEROGENEITY (reported, not hidden): GSE215011 vs the other
# two differ in regimen (monotherapy vs combination) and likely sampling timing
# (GSE279750/GSE235863 are POST-treatment tumor; GSE215011's timing is not
# clearly documented in its GEO metadata). This heterogeneity is a real limitation,
# not resolved by pooling - it is reported explicitly in the forest plot and README.

suppressPackageStartupMessages(library(ggplot2))
source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")

OUT_DIR <- "C:/Users/SAMSUNG/Desktop/project2/results"
FIG_DIR <- "C:/Users/SAMSUNG/Desktop/project2/figures"

# rank-biserial correlation from a Wilcoxon rank-sum test: r_rb = 1 - 2W/(n1*n2)
# (sign convention here: positive = Responder > Non-responder)
rank_biserial <- function(x, group) {
  d <- data.frame(x = x, g = group)
  wt <- wilcox.test(x ~ g, data = d, exact = FALSE)
  n_R <- sum(group == "Responder"); n_NR <- sum(group == "Nonresponder")
  # wilcox.test W = sum of ranks of first level minus its minimum possible value;
  # factor(group) orders alphabetically -> "Nonresponder" is first level, so W
  # corresponds to the Nonresponder group here. Convert to "Responder favored" sign.
  W <- wt$statistic
  r_rb <- 1 - (2 * W) / (n_R * n_NR)
  # bootstrap CI for r_rb
  set.seed(1)
  boot_r <- replicate(2000, {
    idx <- sample(seq_along(x), replace = TRUE)
    xb <- x[idx]; gb <- group[idx]
    if (length(unique(gb)) < 2 || any(table(gb) < 2)) return(NA)
    wtb <- tryCatch(wilcox.test(xb ~ gb, exact = FALSE), error = function(e) NULL)
    if (is.null(wtb)) return(NA)
    1 - (2 * wtb$statistic) / (sum(gb == "Responder") * sum(gb == "Nonresponder"))
  })
  boot_r <- boot_r[!is.na(boot_r)]
  list(r_rb = unname(r_rb), ci_lo = quantile(boot_r, 0.025, na.rm = TRUE),
       ci_hi = quantile(boot_r, 0.975, na.rm = TRUE), p_value = wt$p.value, n = n_R + n_NR)
}

cohorts <- list(
  GSE215011 = list(file = "hcc_ICI_GSE215011_sample_level_data.csv", regimen = "anti-PD-1 monotherapy (nivolumab)"),
  GSE279750 = list(file = "hcc_ICI_GSE279750_sample_level_data.csv", regimen = "anti-PD-L1 combination, post-tx"),
  GSE235863 = list(file = "hcc_ICI_GSE235863_sample_level_data.csv", regimen = "anti-PD-1+lenvatinib combo, post-tx")
)

rows <- lapply(names(cohorts), function(nm) {
  d <- read.csv(file.path(OUT_DIR, cohorts[[nm]]$file))
  rb <- rank_biserial(d$HSF2, d$group)
  data.frame(cohort = nm, regimen = cohorts[[nm]]$regimen, n = rb$n,
             n_R = sum(d$group == "Responder"), n_NR = sum(d$group == "Nonresponder"),
             r_rb = rb$r_rb, ci_lo = rb$ci_lo, ci_hi = rb$ci_hi, p_value = rb$p_value)
})
summary_df <- do.call(rbind, rows)
write.csv(summary_df, file.path(OUT_DIR, "hcc_ICI_POOLED_HSF2_summary.csv"), row.names = FALSE)
cat("=== HSF2: Responder vs Non-responder, rank-biserial effect size, 3 cohorts ===\n")
cat("(positive r_rb = HSF2 higher in Responders; negative = HSF2 lower in Responders)\n")
print(summary_df, row.names = FALSE)

# meta-analyze the rank-biserial correlations (valid: it IS a correlation coefficient)
meta <- meta_cor_DL(summary_df$r_rb, summary_df$n, summary_df$cohort)
cat(sprintf("\n=== Pooled (random-effects, 3 cohorts) ===\npooled r_rb = %.3f, 95%% CI [%.3f, %.3f], p = %.3g, I^2 = %.1f%%\n",
            meta$pooled_rho, meta$ci_lo, meta$ci_hi, meta$p_value, meta$I2))

meta_row <- data.frame(cohort = "Pooled (random-effects)", regimen = "3 cohorts combined", n = sum(summary_df$n),
                        n_R = NA, n_NR = NA, r_rb = meta$pooled_rho, ci_lo = meta$ci_lo, ci_hi = meta$ci_hi,
                        p_value = meta$p_value)
write.csv(rbind(summary_df, meta_row), file.path(OUT_DIR, "hcc_ICI_POOLED_HSF2_with_meta.csv"), row.names = FALSE)

## forest plot
forest_df <- rbind(
  data.frame(label = summary_df$cohort, r_rb = summary_df$r_rb, ci_lo = summary_df$ci_lo,
             ci_hi = summary_df$ci_hi, n = summary_df$n, type = "cohort"),
  data.frame(label = "Pooled (RE)", r_rb = meta$pooled_rho, ci_lo = meta$ci_lo, ci_hi = meta$ci_hi,
             n = sum(summary_df$n), type = "pooled")
)
forest_df$label <- factor(forest_df$label, levels = rev(forest_df$label))
p <- ggplot(forest_df, aes(x = r_rb, y = label, color = type)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.2) +
  geom_point(aes(size = n)) +
  scale_color_manual(values = c(cohort = "steelblue", pooled = "firebrick")) +
  labs(title = "HSF2: Responder vs Non-responder across 3 HCC-ICI cohorts",
       subtitle = "Rank-biserial correlation (Wilcoxon effect size), bootstrap/RE-meta 95% CI - EXPLORATORY, small n",
       x = "Rank-biserial r (positive = HSF2 higher in Responders)", y = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave(file.path(FIG_DIR, "FOREST_hcc_ICI_HSF2_pooled.png"), p, width = 8, height = 4.5, dpi = 300)

cat("\nDone.\n")
