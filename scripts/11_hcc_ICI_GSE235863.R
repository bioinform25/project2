# HCC ICI-response cohort 3: GSE235863 (anti-PD-1 + lenvatinib COMBINATION therapy,
# HBV+ HCC, bulk RNA-seq TPM, POST-treatment liver tumor, n=15: 11 responder(CR/PR)
# / 4 non-responder(SD/PD)). This is a different, more heterogeneous cohort/regimen
# than GSE215011 (nivolumab monotherapy) and GSE279750 (anti-PD-L1 combo) - reported
# separately, not silently pooled, given the regimen/timing differences.

suppressPackageStartupMessages(library(ggplot2))
source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")

DATA_FILE <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE235863/GSE235863_bulk_rna_seq_tpm.txt.gz"
OUT_DIR   <- "C:/Users/SAMSUNG/Desktop/project2/results"
FIG_DIR   <- "C:/Users/SAMSUNG/Desktop/project2/figures"

d <- read.delim(DATA_FILE, header = TRUE, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
patient_cols <- c("P1","P3","P5","P16","P18","P26","P27","P31","P32","P34","P35","P36","P38","P40","P41")
stopifnot(all(patient_cols %in% colnames(d)))

# response labels read from GEO series-matrix sample titles (recon log:
# scripts/exploration/_debug_gse279750_235863_recon.log), "Bulk RNA-seq of
# post-treatment liver tumor of patient PX (response)":
group <- c(P34 = "Nonresponder", P1 = "Nonresponder", P16 = "Nonresponder", P26 = "Nonresponder",
           P18 = "Responder", P27 = "Responder", P3 = "Responder", P31 = "Responder",
           P32 = "Responder", P35 = "Responder", P36 = "Responder", P38 = "Responder",
           P40 = "Responder", P41 = "Responder", P5 = "Responder")
group <- group[patient_cols]
stopifnot(sum(group == "Responder") == 11, sum(group == "Nonresponder") == 4)

panel_all <- unique(c(TARGET_TF, NET_EXTENDED))
d_panel <- d[d$geneName %in% panel_all, c("geneName", patient_cols)]
d_panel <- aggregate(. ~ geneName, data = d_panel, FUN = sum)  # collapse duplicate Ensembl->symbol rows
expr_panel <- as.matrix(d_panel[, patient_cols]); rownames(expr_panel) <- d_panel$geneName
expr_panel_log <- log2(expr_panel + 1)
missing_genes <- setdiff(panel_all, rownames(expr_panel))
cat("Panel genes found:", nrow(expr_panel), "/", length(panel_all), "\n")
if (length(missing_genes) > 0) cat("Missing:", paste(missing_genes, collapse = ", "), "\n")

hsf2 <- expr_panel_log[TARGET_TF, ]
net_core_score <- panel_score(expr_panel_log, NET_CORE, min_genes = 2)
net_ext_score  <- panel_score(expr_panel_log, NET_EXTENDED, min_genes = 4)

df <- data.frame(patient = patient_cols, group = group, HSF2 = hsf2,
                  NET_core = net_core_score, NET_ext = net_ext_score)
write.csv(df, file.path(OUT_DIR, "hcc_ICI_GSE235863_sample_level_data.csv"), row.names = FALSE)

wilcox_report <- function(x, group, label) {
  dd <- data.frame(x = x, g = group)
  wt <- wilcox.test(x ~ g, data = dd, exact = FALSE)  # ties likely with n=15, use normal approx
  data.frame(comparison = label,
             n_R = sum(group == "Responder"), n_NR = sum(group == "Nonresponder"),
             mean_R = mean(dd$x[dd$g == "Responder"]), mean_NR = mean(dd$x[dd$g == "Nonresponder"]),
             diff_R_minus_NR = mean(dd$x[dd$g == "Responder"]) - mean(dd$x[dd$g == "Nonresponder"]),
             p_value = wt$p.value)
}

res <- rbind(
  wilcox_report(df$HSF2, df$group, "HSF2: Responder vs Non-responder"),
  wilcox_report(df$NET_core, df$group, "NET_core: Responder vs Non-responder"),
  wilcox_report(df$NET_ext, df$group, "NET_extended: Responder vs Non-responder")
)
cor_res <- spearman_report(df$HSF2, df$NET_core, "GSE235863_HCC: HSF2 vs NET_core (all 15 tumors)")

write.csv(res, file.path(OUT_DIR, "hcc_ICI_GSE235863_group_comparison.csv"), row.names = FALSE)
write.csv(cor_res, file.path(OUT_DIR, "hcc_ICI_GSE235863_HSF2_vs_NETcore.csv"), row.names = FALSE)

cat("\n=== HSF2/NET_core: Responder vs Non-responder (Wilcoxon, n=11 vs 4, EXPLORATORY) ===\n")
print(res, row.names = FALSE)
cat("\n=== HSF2 vs NET_core correlation across all 15 tumors ===\n")
print(cor_res, row.names = FALSE)

df$group_f <- factor(df$group, levels = c("Nonresponder", "Responder"))
p1 <- ggplot(df, aes(x = group_f, y = HSF2)) +
  geom_boxplot(outlier.shape = NA) + geom_jitter(width = 0.1, size = 2) +
  labs(title = "GSE235863 (HCC, anti-PD-1+lenvatinib combo, post-tx, n=15)",
       subtitle = sprintf("HSF2: Wilcoxon p = %.3f (EXPLORATORY, n=11 vs 4)", res$p_value[1]),
       x = NULL, y = "HSF2 (log2 TPM+1)") +
  theme_bw()
ggsave(file.path(FIG_DIR, "hcc_ICI_GSE235863_HSF2_by_response.png"), p1, width = 5.5, height = 5, dpi = 300)

p3 <- ggplot(df, aes(x = HSF2, y = NET_core, color = group_f)) +
  geom_point(size = 2.5) +
  labs(title = "GSE235863 (HCC): HSF2 vs NET_core, all 15 tumors",
       subtitle = sprintf("Spearman rho = %.2f, p = %.2g (n=15, EXPLORATORY)", cor_res$rho, cor_res$p_value),
       x = "HSF2 (log2 TPM+1)", y = "NET_core score", color = "ICI response") +
  theme_bw()
ggsave(file.path(FIG_DIR, "hcc_ICI_GSE235863_HSF2_vs_NETcore.png"), p3, width = 6.5, height = 5, dpi = 300)

cat("\nDone.\n")
