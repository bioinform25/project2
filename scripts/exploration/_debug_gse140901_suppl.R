suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE140901"
gset <- getGEO("GSE140901", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
es <- gset[[1]]
pd <- pData(es)
cat("supplementary_file:\n")
print(unique(pd$supplementary_file))
cat("\nbest_response:ch1:\n"); print(table(pd$`best_response:ch1`, useNA="always"))
cat("\nclinical_benefit_response:ch1:\n"); print(table(pd$`clinical_benefit_response:ch1`, useNA="always"))
cat("\ndisease state:ch1:\n"); print(table(pd$`disease state:ch1`, useNA="always"))
cat("\netiology:ch1:\n"); print(table(pd$`etiology:ch1`, useNA="always"))

# try downloading GSE-level supplementary files (raw NanoString counts likely here)
gse_suppl <- getGEOSuppFiles("GSE140901", baseDir = DATA_DIR, makeDirectory = FALSE)
print(gse_suppl)
