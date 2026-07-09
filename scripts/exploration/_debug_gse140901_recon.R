suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE140901"
gset <- getGEO("GSE140901", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
cat("n platforms:", length(gset), "\n")
for (i in seq_along(gset)) {
  es <- gset[[i]]
  cat("\n=== gset[[", i, "]]", annotation(es), "n=", ncol(es), "===\n")
  cat("dim:", dim(es), "\n")
  print(colnames(pData(es)))
}
