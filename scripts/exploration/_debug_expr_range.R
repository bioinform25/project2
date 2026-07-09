suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/HSF2_NETosis_fibrosis/data/GSE14323"
gset <- getGEO("GSE14323", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
es <- gset[[1]]
m <- exprs(es)
cat("range:", range(m), "\n")
cat("quantiles:\n"); print(quantile(m, probs = c(0,0.01,0.25,0.5,0.75,0.99,1)))
cat("\ndata_processing field:\n")
print(unique(pData(es)$data_processing))
