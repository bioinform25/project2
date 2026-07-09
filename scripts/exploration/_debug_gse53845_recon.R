suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/HSF2_NETosis_fibrosis/data/GSE53845"
gset <- getGEO("GSE53845", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE)
cat("n platforms:", length(gset), "\n")
es <- gset[[1]]
cat("dim:", dim(es), " platform:", annotation(es), "\n")
print(colnames(pData(es)))
cat("-- disease/group-like columns --\n")
pd <- pData(es)
for (cn in colnames(pd)) {
  if (grepl("disease|group|diagnosis|tissue|status|characteristics", cn, ignore.case=TRUE)) {
    cat("\n", cn, ":\n"); print(table(pd[[cn]], useNA="always"))
  }
}
cat("range expr:", range(exprs(es)), "\n")
fd <- fData(es)
cat("fData cols:", paste(colnames(fd), collapse=", "), "\n")
