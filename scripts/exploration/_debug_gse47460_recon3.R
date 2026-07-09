suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/HSF2_NETosis_fibrosis/data/GSE47460"
gset <- getGEO("GSE47460", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
es1 <- gset[[1]]; es2 <- gset[[2]]
cat("--- data_processing (GPL14550) ---\n"); print(unique(pData(es1)$data_processing))
cat("\n--- fData(es2) cols (GPL6480) ---\n"); print(colnames(fData(es2)))
cat("\n--- gset2 disease state ---\n"); print(table(pData(es2)$`disease state:ch1`))
cat("\n--- gset2 ild subtype ---\n"); print(table(pData(es2)$`ild subtype:ch1`))
fd1 <- fData(es1)
hit1 <- fd1[fd1$GENE_SYMBOL %in% c("HSF2","PADI4","ELANE","MPO"), c("ID","GENE_SYMBOL")]
cat("\nGPL14550 HSF2/NET probes:\n"); print(hit1)
fd2 <- fData(es2)
symcol2 <- grep("symbol", colnames(fd2), ignore.case=TRUE, value=TRUE)
cat("\nGPL6480 symbol-like columns:", symcol2, "\n")
