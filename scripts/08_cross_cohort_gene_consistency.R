# Cross-cohort consistency table for individual NET-panel genes vs HSF2.
# Purpose: ground the wet-lab biomarker panel recommendation in actual replicated
# signal (direction + FDR significance) across the 4 fibrosis cohorts, rather than
# relying on any single cohort or on recall.

OUT_DIR <- "C:/Users/SAMSUNG/Desktop/project2/results"

files <- c(
  liver_GSE135251 = "liver_GSE135251_individual_gene_results.csv",
  liver_GSE14323  = "liver_GSE14323_individual_gene_results.csv",
  lung_GSE47460   = "lung_GSE47460_individual_gene_results.csv",
  lung_GSE53845   = "lung_GSE53845_individual_gene_results.csv"
)

extract_gene <- function(comparison_str) {
  # format: "<COHORT>: HSF2 vs <GENE> (<subset>)"
  sub(".*HSF2 vs ([A-Za-z0-9]+).*", "\\1", comparison_str)
}

long <- do.call(rbind, lapply(names(files), function(nm) {
  d <- read.csv(file.path(OUT_DIR, files[nm]))
  d$gene <- sapply(d$comparison, extract_gene)
  d$cohort <- nm
  d[, c("cohort", "gene", "n", "rho", "p_value", "p_FDR")]
}))

wide_rho <- reshape(long[, c("cohort","gene","rho")], idvar = "gene", timevar = "cohort", direction = "wide")
wide_fdr <- reshape(long[, c("cohort","gene","p_FDR")], idvar = "gene", timevar = "cohort", direction = "wide")
names(wide_rho) <- sub("^rho\\.", "", names(wide_rho))
names(wide_fdr) <- sub("^p_FDR\\.", "", names(wide_fdr))

cohort_names <- names(files)
consistency <- merge(wide_rho, wide_fdr, by = "gene", suffixes = c("_rho", "_FDR"))

# summary columns: how many cohorts tested, how many FDR<0.05, sign consistency
rho_cols <- paste0(cohort_names, "_rho")
fdr_cols <- paste0(cohort_names, "_FDR")
consistency$n_cohorts_tested <- rowSums(!is.na(consistency[, rho_cols]))
consistency$n_cohorts_sig_FDR05 <- rowSums(consistency[, fdr_cols] < 0.05, na.rm = TRUE)
sign_mat <- sign(consistency[, rho_cols])
consistency$n_negative <- rowSums(sign_mat < 0, na.rm = TRUE)
consistency$n_positive <- rowSums(sign_mat > 0, na.rm = TRUE)
consistency$direction_consistent <- (consistency$n_negative == consistency$n_cohorts_tested) |
                                     (consistency$n_positive == consistency$n_cohorts_tested)

consistency <- consistency[order(-consistency$n_cohorts_sig_FDR05, -consistency$n_cohorts_tested), ]
col_order <- c("gene", rho_cols, fdr_cols, "n_cohorts_tested", "n_cohorts_sig_FDR05",
               "direction_consistent", "n_negative", "n_positive")
consistency <- consistency[, col_order]

write.csv(consistency, file.path(OUT_DIR, "CROSS_COHORT_gene_consistency.csv"), row.names = FALSE)
cat("=== Cross-cohort consistency (HSF2 vs each NET panel gene) ===\n")
print(consistency, row.names = FALSE, digits = 3)
