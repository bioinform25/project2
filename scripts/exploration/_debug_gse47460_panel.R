suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/HSF2_NETosis_fibrosis/data/GSE47460"
gset <- getGEO("GSE47460", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
es1 <- gset[[1]]
fd1 <- fData(es1)
panel <- c("HSF2","PADI4","ELANE","MPO","CTSG","LTF","CAMP","DEFA4","AZU1","ITGAM","NCF2","S100A12","LCN2")
hit <- fd1[fd1$GENE_SYMBOL %in% panel, c("ID","GENE_SYMBOL")]
print(hit)
cat("Missing:", paste(setdiff(panel, hit$GENE_SYMBOL), collapse=", "), "\n")
