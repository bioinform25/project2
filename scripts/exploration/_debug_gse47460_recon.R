suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/HSF2_NETosis_fibrosis/data/GSE47460"
gset <- getGEO("GSE47460", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
cat("n platforms:", length(gset), "\n")
for (i in seq_along(gset)) {
  es <- gset[[i]]
  cat("\n=========== gset[[", i, "]] :", annotation(es), "===========\n")
  cat("dim:", dim(es), "\n")
  print(colnames(pData(es)))
}
