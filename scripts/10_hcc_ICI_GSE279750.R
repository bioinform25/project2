# HCC ICI-response cohort 2: GSE279750 (first-line anti-PD-L1-based combination
# immunotherapy, surgical tumor specimens post->3mo treatment, whole-transcriptome
# per-sample xlsx tables, n=10: 4 non-responder / 6 responder).
# Same exploratory group-comparison design as GSE215011 (07_hcc_ICI_GSE215011.R).
# NOTE: samples here are POST-treatment (not baseline/pre-treatment like GSE215011),
# and the regimen is a PD-L1-based COMBINATION (not PD-1 monotherapy) - a genuine
# clinical/design difference from GSE215011, flagged rather than pooled naively.

suppressPackageStartupMessages({ library(readxl); library(ggplot2) })
source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")

DATA_DIR <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE279750/extracted"
OUT_DIR  <- "C:/Users/SAMSUNG/Desktop/project2/results"
FIG_DIR  <- "C:/Users/SAMSUNG/Desktop/project2/figures"

files <- list.files(DATA_DIR, pattern = "\\.xlsx$", full.names = TRUE)
sample_ids <- sub("^GSM[0-9]+_(.*)\\.xlsx$", "\\1", basename(files))
cat("Samples:", paste(sample_ids, collapse = ", "), "\n")

mats <- lapply(files, function(f) {
  d <- read_excel(f, sheet = 1)
  colnames(d) <- c("gene_id", "expr")
  d
})
names(mats) <- sample_ids

all_genes <- Reduce(intersect, lapply(mats, function(d) d$gene_id))
expr_mat <- sapply(mats, function(d) d$expr[match(all_genes, d$gene_id)])
rownames(expr_mat) <- all_genes
cat("Merged expr matrix dim:", dim(expr_mat), "\n")

group <- ifelse(grepl("^NR", sample_ids), "Nonresponder", "Responder")
names(group) <- sample_ids
stopifnot(sum(group == "Responder") == 6, sum(group == "Nonresponder") == 4)

panel_all <- unique(c(TARGET_TF, NET_EXTENDED))
expr_panel <- expr_mat[intersect(panel_all, rownames(expr_mat)), , drop = FALSE]
expr_panel_log <- log2(expr_panel + 1)
missing_genes <- setdiff(panel_all, rownames(expr_panel))
cat("Panel genes found:", nrow(expr_panel), "/", length(panel_all), "\n")
if (length(missing_genes) > 0) cat("Missing:", paste(missing_genes, collapse = ", "), "\n")

hsf2 <- expr_panel_log[TARGET_TF, ]
net_core_score <- panel_score(expr_panel_log, NET_CORE, min_genes = 2)
net_ext_score  <- panel_score(expr_panel_log, NET_EXTENDED, min_genes = 4)

df <- data.frame(sample = sample_ids, group = group, HSF2 = hsf2,
                  NET_core = net_core_score, NET_ext = net_ext_score)
write.csv(df, file.path(OUT_DIR, "hcc_ICI_GSE279750_sample_level_data.csv"), row.names = FALSE)

wilcox_report <- function(x, group, label) {
  d <- data.frame(x = x, g = group)
  wt <- wilcox.test(x ~ g, data = d, exact = TRUE)
  data.frame(comparison = label,
             n_R = sum(group == "Responder"), n_NR = sum(group == "Nonresponder"),
             mean_R = mean(d$x[d$g == "Responder"]), mean_NR = mean(d$x[d$g == "Nonresponder"]),
             diff_R_minus_NR = mean(d$x[d$g == "Responder"]) - mean(d$x[d$g == "Nonresponder"]),
             p_value = wt$p.value)
}

res <- rbind(
  wilcox_report(df$HSF2, df$group, "HSF2: Responder vs Non-responder"),
  wilcox_report(df$NET_core, df$group, "NET_core: Responder vs Non-responder"),
  wilcox_report(df$NET_ext, df$group, "NET_extended: Responder vs Non-responder")
)
cor_res <- spearman_report(df$HSF2, df$NET_core, "GSE279750_HCC: HSF2 vs NET_core (all 10 tumors)")

write.csv(res, file.path(OUT_DIR, "hcc_ICI_GSE279750_group_comparison.csv"), row.names = FALSE)
write.csv(cor_res, file.path(OUT_DIR, "hcc_ICI_GSE279750_HSF2_vs_NETcore.csv"), row.names = FALSE)

cat("\n=== HSF2/NET_core: Responder vs Non-responder (Wilcoxon, n=6 vs 4, EXPLORATORY) ===\n")
print(res, row.names = FALSE)
cat("\n=== HSF2 vs NET_core correlation across all 10 tumors ===\n")
print(cor_res, row.names = FALSE)

df$group_f <- factor(df$group, levels = c("Nonresponder", "Responder"))
p1 <- ggplot(df, aes(x = group_f, y = HSF2)) +
  geom_boxplot(outlier.shape = NA) + geom_jitter(width = 0.1, size = 2) +
  labs(title = "GSE279750 (HCC, anti-PD-L1 combo, post-tx, n=10)",
       subtitle = sprintf("HSF2: Wilcoxon p = %.3f (EXPLORATORY, n=6 vs 4)", res$p_value[1]),
       x = NULL, y = "HSF2 (log2 expr+1)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "hcc_ICI_GSE279750_HSF2_by_response.png"), p1, width = 5.5, height = 5, dpi = 300)

p3 <- ggplot(df, aes(x = HSF2, y = NET_core, color = group_f)) +
  geom_point(size = 2.5) +
  labs(title = "GSE279750 (HCC): HSF2 vs NET_core, all 10 tumors",
       subtitle = sprintf("Spearman rho = %.2f, p = %.2g (n=10, EXPLORATORY)", cor_res$rho, cor_res$p_value),
       x = "HSF2 (log2 expr+1)", y = "NET_core score", color = "ICI response") +
  theme_bw()
ggsave(file.path(FIG_DIR, "hcc_ICI_GSE279750_HSF2_vs_NETcore.png"), p3, width = 6.5, height = 5, dpi = 300)

cat("\nDone.\n")
