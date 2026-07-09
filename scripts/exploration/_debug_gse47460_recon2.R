suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/HSF2_NETosis_fibrosis/data/GSE47460"
gset <- getGEO("GSE47460", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
for (i in seq_along(gset)) {
  es <- gset[[i]]
  cat("\n=== gset[[", i, "]]", annotation(es), "n=", ncol(es), "===\n")
  cat("-- disease state --\n"); print(table(pData(es)$`disease state:ch1`, useNA="always"))
  cat("-- ild subtype --\n"); print(table(pData(es)$`ild subtype:ch1`, useNA="always"))
  cat("range expr:", range(exprs(es)), "\n")
  fd <- fData(es)
  cat("fData cols:", paste(colnames(fd), collapse=", "), "\n")
  hit <- fd[fd$`Gene symbol` %in% c("HSF2","PADI4"), c("ID","Gene symbol")]
  cat("HSF2/PADI4 probes:\n"); print(head(hit, 6))
}
