suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/HSF2_NETosis_fibrosis/data/GSE14323"
gset <- getGEO("GSE14323", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
for (i in seq_along(gset)) {
  es <- gset[[i]]
  cat("\n\n=========== gset[[", i, "]] : ", annotation(es), " ===========\n")
  cat("dim:", dim(es), "\n")
  tt <- table(pData(es)$`Tissue:ch1`)
  print(tt)
  fd <- fData(es)
  hit <- fd[fd$`Gene symbol` %in% c("HSF2","PADI4","ELANE","MPO","CTSG","LTF","AZU1"), c("ID","Gene symbol")]
  cat("Probe hits for target genes:\n"); print(hit)
}
