# HCC immune-checkpoint-inhibitor response cohort: GSE215011 (nivolumab monotherapy,
# anti-PD-1, tumor RNA-seq, n=10: 5 responder / 5 non-responder). This is the only
# candidate ICI-response dataset found where HSF2 AND all 3 NET_core genes
# (PADI4/ELANE/MPO) are actually measured - GSE140901 (NanoString 785-gene panel)
# and GSE202069 (NanoString 289-gene panel) were checked first and BOTH lack HSF2
# entirely (see scripts/exploration/_debug_gse140901_suppl.R), so were excluded
# rather than forced with a substitute readout.
#
# IMPORTANT POWER CAVEAT: n=10 (5 vs 5) only reaches significance for very large
# effect sizes. This analysis is reported as exploratory/hypothesis-generating,
# not as a confirmatory test, regardless of outcome - consistent with how the
# underpowered GSE53845 lung replication (n=40) was handled in the main pipeline.

suppressPackageStartupMessages(library(ggplot2))
source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")

DATA_FILE <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE215011/GSE215011_gene_description_human_samples.txt.gz"
OUT_DIR   <- "C:/Users/SAMSUNG/Desktop/project2/results"
FIG_DIR   <- "C:/Users/SAMSUNG/Desktop/project2/figures"

d <- read.delim(DATA_FILE, header = TRUE, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
sample_cols <- c("A12_949T","A16_557T","A17_152T","A19_16T","A19_171T",
                  "A11_385T","A18_440T","A19_1T","A19_121T","A19_174T")
stopifnot(all(sample_cols %in% colnames(d)))

group <- c(A12_949T = "Nonresponder", A16_557T = "Nonresponder", A17_152T = "Nonresponder",
           A19_16T = "Nonresponder", A11_385T = "Nonresponder",
           A18_440T = "Responder", A19_121T = "Responder", A19_171T = "Responder",
           A19_174T = "Responder", A19_1T = "Responder")
# cross-check against GEO series-matrix "title"/"group:ch1" characteristics captured during recon:
# Non-Responder: A11_385T, A12_949T, A16_557T, A17_152T, A19_16T
# Responder:     A18_440T, A19_121T, A19_171T, A19_174T, A19_1T
group <- group[sample_cols]
stopifnot(sum(group == "Responder") == 5, sum(group == "Nonresponder") == 5)

panel_all <- unique(c(TARGET_TF, NET_EXTENDED))
d_panel <- d[d$gene_name %in% panel_all, c("gene_name", sample_cols)]
# collapse any duplicate gene_name rows (multiple Ensembl IDs per symbol) by summing counts
d_panel <- aggregate(. ~ gene_name, data = d_panel, FUN = sum)
expr_panel <- as.matrix(d_panel[, sample_cols])
rownames(expr_panel) <- d_panel$gene_name
expr_panel_log <- log2(expr_panel + 1)

missing_genes <- setdiff(panel_all, rownames(expr_panel))
cat("Panel genes found:", nrow(expr_panel), "/", length(panel_all), "\n")
if (length(missing_genes) > 0) cat("Missing:", paste(missing_genes, collapse = ", "), "\n")

hsf2 <- expr_panel_log[TARGET_TF, ]
net_core_score <- panel_score(expr_panel_log, NET_CORE, min_genes = 2)
net_ext_score  <- panel_score(expr_panel_log, NET_EXTENDED, min_genes = 4)

df <- data.frame(sample = sample_cols, group = group, HSF2 = hsf2,
                  NET_core = net_core_score, NET_ext = net_ext_score)
write.csv(df, file.path(OUT_DIR, "hcc_ICI_GSE215011_sample_level_data.csv"), row.names = FALSE)

## ---- Pre-specified tests (exploratory given n=10) ------------------------------
wilcox_report <- function(x, group, label) {
  d <- data.frame(x = x, g = group)
  wt <- wilcox.test(x ~ g, data = d, exact = TRUE)
  eff <- (mean(d$x[d$g == "Responder"]) - mean(d$x[d$g == "Nonresponder"]))
  data.frame(comparison = label,
             n_R = sum(group == "Responder"), n_NR = sum(group == "Nonresponder"),
             mean_R = mean(d$x[d$g == "Responder"]), mean_NR = mean(d$x[d$g == "Nonresponder"]),
             diff_R_minus_NR = eff, p_value = wt$p.value)
}

res <- rbind(
  wilcox_report(df$HSF2, df$group, "HSF2: Responder vs Non-responder"),
  wilcox_report(df$NET_core, df$group, "NET_core: Responder vs Non-responder"),
  wilcox_report(df$NET_ext, df$group, "NET_extended: Responder vs Non-responder")
)
cor_res <- spearman_report(df$HSF2, df$NET_core, "GSE215011_HCC: HSF2 vs NET_core (all 10 tumors)")

write.csv(res, file.path(OUT_DIR, "hcc_ICI_GSE215011_group_comparison.csv"), row.names = FALSE)
write.csv(cor_res, file.path(OUT_DIR, "hcc_ICI_GSE215011_HSF2_vs_NETcore.csv"), row.names = FALSE)

cat("\n=== HSF2/NET_core: Responder vs Non-responder (Wilcoxon, n=5 vs 5, EXPLORATORY) ===\n")
print(res, row.names = FALSE)
cat("\n=== HSF2 vs NET_core correlation across all 10 tumors ===\n")
print(cor_res, row.names = FALSE)

## ---- Figures ---------------------------------------------------------------------
df$group_f <- factor(df$group, levels = c("Nonresponder", "Responder"))
p1 <- ggplot(df, aes(x = group_f, y = HSF2)) +
  geom_boxplot(outlier.shape = NA) + geom_jitter(width = 0.1, size = 2) +
  labs(title = "GSE215011 (HCC, anti-PD-1 monotherapy, n=10)",
       subtitle = sprintf("HSF2: Wilcoxon p = %.3f (EXPLORATORY, n=5 vs 5)", res$p_value[1]),
       x = NULL, y = "HSF2 (log2 expr+1)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "hcc_ICI_GSE215011_HSF2_by_response.png"), p1, width = 5.5, height = 5, dpi = 300)

p2 <- ggplot(df, aes(x = group_f, y = NET_core)) +
  geom_boxplot(outlier.shape = NA) + geom_jitter(width = 0.1, size = 2) +
  labs(title = "GSE215011 (HCC, anti-PD-1 monotherapy, n=10)",
       subtitle = sprintf("NET_core: Wilcoxon p = %.3f (EXPLORATORY, n=5 vs 5)", res$p_value[2]),
       x = NULL, y = "NET_core score (z-mean: PADI4/ELANE/MPO)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "hcc_ICI_GSE215011_NETcore_by_response.png"), p2, width = 5.5, height = 5, dpi = 300)

p3 <- ggplot(df, aes(x = HSF2, y = NET_core, color = group_f)) +
  geom_point(size = 2.5) +
  labs(title = "GSE215011 (HCC): HSF2 vs NET_core, all 10 tumors",
       subtitle = sprintf("Spearman rho = %.2f, p = %.2g (n=10, EXPLORATORY)", cor_res$rho, cor_res$p_value),
       x = "HSF2 (log2 expr+1)", y = "NET_core score", color = "ICI response") +
  theme_bw()
ggsave(file.path(FIG_DIR, "hcc_ICI_GSE215011_HSF2_vs_NETcore.png"), p3, width = 6.5, height = 5, dpi = 300)

cat("\nDone.\n")
