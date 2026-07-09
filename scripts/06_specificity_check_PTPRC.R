# Specificity control: does HSF2 negatively correlate specifically with the
# NETosis/neutrophil-granule signature, or does it negatively correlate with
# ANY immune infiltration marker (which would instead point to a trivial bulk-
# tissue cell-composition dilution artifact: more immune infiltrate -> lower
# relative parenchymal-cell-derived reads incl. HSF2)?
# Test: add PTPRC (CD45, pan-leukocyte marker) and compare its correlation with
# HSF2 against the NET_core correlation, in the same two liver cohorts (largest,
# most powered primary+replication pair).

suppressPackageStartupMessages({
  library(DESeq2); library(org.Hs.eg.db); library(AnnotationDbi); library(GEOquery); library(Biobase)
})
source("C:/Users/SAMSUNG/Desktop/project2/scripts/00_functions.R")
OUT_DIR <- "C:/Users/SAMSUNG/Desktop/project2/results"

## ---- GSE135251 (liver, RNA-seq) -------------------------------------------------
liver1 <- readRDS(file.path(OUT_DIR, "liver_GSE135251_full_output.rds"))
RAW_DIR <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE135251_RAW"
files <- list.files(RAW_DIR, pattern = "\\.counts\\.txt$", full.names = TRUE)
file_gsm <- sub("_.*$", "", basename(files))
gsm_order <- liver1$df$gsm
files <- files[match(gsm_order, file_gsm)]
first <- read.table(files[1], header = FALSE, sep = "\t", stringsAsFactors = FALSE)
gene_ids <- first[[1]]
counts <- matrix(NA_integer_, nrow = length(gene_ids), ncol = length(files), dimnames = list(gene_ids, gsm_order))
for (i in seq_along(files)) {
  d <- read.table(files[i], header = FALSE, sep = "\t", stringsAsFactors = FALSE)
  counts[, i] <- d[[2]]
}
ptprc_ens <- AnnotationDbi::select(org.Hs.eg.db, keys = "PTPRC", keytype = "SYMBOL", columns = "ENSEMBL")$ENSEMBL
ptprc_ens <- intersect(ptprc_ens, rownames(counts))
keep <- (rowMeans(counts) >= 10) | (rownames(counts) %in% ptprc_ens)
dds <- DESeqDataSetFromMatrix(counts[keep, ], colData = data.frame(gsm = gsm_order), design = ~1)
dds <- estimateSizeFactors(dds)
vsd <- assay(vst(dds, blind = TRUE))
ptprc_expr <- colMeans(vsd[ptprc_ens, , drop = FALSE])

df1 <- liver1$df
df1$PTPRC <- ptprc_expr[match(df1$gsm, names(ptprc_expr))]
df1_dis <- df1[df1$disease == "NAFLD", ]
r1_ptprc <- spearman_report(df1_dis$HSF2, df1_dis$PTPRC, "GSE135251_liver: HSF2 vs PTPRC (NAFLD subset)")
r1_netcore <- spearman_report(df1_dis$HSF2, df1_dis$NET_core, "GSE135251_liver: HSF2 vs NET_core (NAFLD subset) [repeat]")
r1_ptprc_netcore <- spearman_report(df1_dis$PTPRC, df1_dis$NET_core, "GSE135251_liver: PTPRC vs NET_core (NAFLD subset)")

## ---- GSE14323 (liver, microarray) -----------------------------------------------
gset <- getGEO("GSE14323", destdir = "C:/Users/SAMSUNG/Desktop/project2/data/GSE14323",
                GSEMatrix = TRUE, AnnotGPL = TRUE)
es <- gset[[1]]
fd <- fData(es); expr <- exprs(es)
ptprc_hits <- fd[fd$`Gene symbol` == "PTPRC", c("ID", "Gene symbol")]
ptprc_hits$mean_expr <- rowMeans(expr[ptprc_hits$ID, , drop = FALSE])
ptprc_probe <- ptprc_hits$ID[which.max(ptprc_hits$mean_expr)]
ptprc_expr2 <- setNames(expr[ptprc_probe, ], colnames(es))

liver2 <- readRDS(file.path(OUT_DIR, "liver_GSE14323_full_output.rds"))
df2 <- liver2$df
df2$PTPRC <- ptprc_expr2[match(df2$gsm, names(ptprc_expr2))]
df2_dis <- df2[df2$tissue != "Normal", ]
r2_ptprc <- spearman_report(df2_dis$HSF2, df2_dis$PTPRC, "GSE14323_liver: HSF2 vs PTPRC (diseased subset)")
r2_netcore <- spearman_report(df2_dis$HSF2, df2_dis$NET_core, "GSE14323_liver: HSF2 vs NET_core (diseased subset) [repeat]")
r2_ptprc_netcore <- spearman_report(df2_dis$PTPRC, df2_dis$NET_core, "GSE14323_liver: PTPRC vs NET_core (diseased subset)")

out <- rbind(r1_ptprc, r1_netcore, r1_ptprc_netcore, r2_ptprc, r2_netcore, r2_ptprc_netcore)
write.csv(out, file.path(OUT_DIR, "SPECIFICITY_check_PTPRC_vs_NETcore.csv"), row.names = FALSE)
cat("=== Specificity check: HSF2 vs PTPRC (pan-leukocyte) vs HSF2 vs NET_core ===\n")
print(out[, c("comparison", "n", "rho", "p_value")], row.names = FALSE)
