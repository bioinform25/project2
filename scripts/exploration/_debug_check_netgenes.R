suppressPackageStartupMessages({library(org.Hs.eg.db); library(AnnotationDbi)})
RAW_DIR <- "C:/Users/SAMSUNG/Desktop/5-1 1~2/GSE135251/unzip/GSE135251_RAW"
files <- list.files(RAW_DIR, pattern = "\\.counts\\.txt$", full.names = TRUE)
first <- read.table(files[1], header = FALSE, sep = "\t", stringsAsFactors = FALSE)
gene_ids <- first[[1]]
counts <- matrix(NA_integer_, nrow = length(gene_ids), ncol = length(files),
                  dimnames = list(gene_ids, basename(files)))
for (i in seq_along(files)) {
  d <- read.table(files[i], header = FALSE, sep = "\t", stringsAsFactors = FALSE)
  counts[, i] <- d[[2]]
}
genes <- c("PADI4", "ELANE", "MPO", "CAMP", "DEFA4", "AZU1", "S100A12")
m <- suppressMessages(AnnotationDbi::select(org.Hs.eg.db, keys = genes, keytype = "SYMBOL", columns = "ENSEMBL"))
m <- m[!is.na(m$ENSEMBL) & m$ENSEMBL %in% rownames(counts), ]
print(m)
for (i in seq_len(nrow(m))) {
  v <- counts[m$ENSEMBL[i], ]
  cat(sprintf("%s (%s): mean=%.2f median=%.1f max=%d pct_zero=%.1f%%\n",
              m$SYMBOL[i], m$ENSEMBL[i], mean(v), median(v), max(v), 100 * mean(v == 0)))
}
