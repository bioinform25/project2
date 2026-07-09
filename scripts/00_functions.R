# Shared functions and definitions for HSF2-NETosis fibrosis cross-organ analysis
# Pre-specified analysis plan (write BEFORE looking at correlation results):
#   Primary endpoint : Spearman rho(HSF2, NET_core_score) within diseased/fibrotic samples
#   NET_core genes   : PADI4, ELANE, MPO  (direct NETosis machinery, mechanistically required)
#   NET_extended     : core + CTSG, LTF, CAMP, DEFA4, AZU1, ITGAM, NCF2, S100A12, LCN2
#                       (broader neutrophil granule/NETosis-associated signature; secondary/robustness)
#   Significance     : primary endpoint tested at alpha = 0.05, two-sided, per cohort
#   Individual-gene correlations (HSF2 vs each panel gene) are secondary/exploratory -> BH-FDR
#   Replication rule : a finding counts as "replicated" only if primary + replication cohort
#                       agree in sign AND both are nominally significant (p < 0.05)

NET_CORE     <- c("PADI4", "ELANE", "MPO")
NET_EXTENDED <- c(NET_CORE, "CTSG", "LTF", "CAMP", "DEFA4", "AZU1", "ITGAM", "NCF2", "S100A12", "LCN2")
TARGET_TF    <- "HSF2"

suppressPackageStartupMessages({
  library(dplyr)
  library(boot)
})

zscore <- function(x) {
  (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
}

# Mean of per-gene z-scores across a panel; requires >=2 genes present to be meaningful
panel_score <- function(expr_mat, genes, min_genes = 2) {
  present <- intersect(genes, rownames(expr_mat))
  if (length(present) < min_genes) {
    warning(sprintf("Only %d/%d panel genes present (min_genes=%d) - score unreliable",
                     length(present), length(genes), min_genes))
  }
  z <- t(apply(expr_mat[present, , drop = FALSE], 1, zscore))
  colMeans(z, na.rm = TRUE)
}

# Bootstrap 95% CI (percentile method) for Spearman rho
boot_spearman_ci <- function(x, y, R = 2000, seed = 1) {
  set.seed(seed)
  d <- data.frame(x = x, y = y)
  d <- d[complete.cases(d), ]
  stat_fn <- function(data, idx) {
    suppressWarnings(cor(data$x[idx], data$y[idx], method = "spearman"))
  }
  b <- boot(d, stat_fn, R = R)
  ci <- tryCatch(boot.ci(b, type = "perc")$percent[4:5], error = function(e) c(NA, NA))
  list(rho = b$t0, ci_lo = ci[1], ci_hi = ci[2], n = nrow(d))
}

# Leave-one-out sensitivity: how much does rho move when each sample is dropped?
loo_spearman <- function(x, y) {
  d <- data.frame(x = x, y = y)
  d <- d[complete.cases(d), ]
  n <- nrow(d)
  rhos <- sapply(seq_len(n), function(i) {
    suppressWarnings(cor(d$x[-i], d$y[-i], method = "spearman"))
  })
  rhos
}

# Spearman test + effect size + bootstrap CI, packaged into one row
spearman_report <- function(x, y, label, R = 2000) {
  ct <- suppressWarnings(cor.test(x, y, method = "spearman", exact = FALSE))
  ci <- boot_spearman_ci(x, y, R = R)
  loo <- loo_spearman(x, y)
  data.frame(
    comparison = label,
    n          = ci$n,
    rho        = unname(ct$estimate),
    p_value    = ct$p.value,
    ci_lo      = ci$ci_lo,
    ci_hi      = ci$ci_hi,
    loo_rho_min = min(loo, na.rm = TRUE),
    loo_rho_max = max(loo, na.rm = TRUE)
  )
}

# Fisher z-transform random-effects (DerSimonian-Laird) meta-analysis of correlation coefficients
# implemented from scratch (no 'metafor' dependency) for transparency in Methods.
meta_cor_DL <- function(rho, n, labels) {
  z  <- atanh(rho)                # Fisher's z
  se <- 1 / sqrt(n - 3)
  w_fixed <- 1 / se^2
  z_fixed <- sum(w_fixed * z) / sum(w_fixed)
  Q  <- sum(w_fixed * (z - z_fixed)^2)
  dfree <- length(rho) - 1
  tau2 <- max(0, (Q - dfree) / (sum(w_fixed) - sum(w_fixed^2) / sum(w_fixed)))
  w_re <- 1 / (se^2 + tau2)
  z_re <- sum(w_re * z) / sum(w_re)
  se_re <- sqrt(1 / sum(w_re))
  ci_lo <- tanh(z_re - 1.96 * se_re)
  ci_hi <- tanh(z_re + 1.96 * se_re)
  p_re  <- 2 * pnorm(-abs(z_re / se_re))
  I2 <- max(0, (Q - dfree) / Q) * 100
  list(
    per_study = data.frame(label = labels, rho = rho, n = n, weight_re = w_re / sum(w_re)),
    pooled_rho = tanh(z_re), ci_lo = ci_lo, ci_hi = ci_hi, p_value = p_re,
    Q = Q, df = dfree, I2 = I2, tau2 = tau2
  )
}
