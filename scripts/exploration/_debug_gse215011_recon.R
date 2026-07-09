suppressPackageStartupMessages({library(GEOquery); library(Biobase)})
DATA_DIR <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE215011"
dir.create(DATA_DIR, showWarnings = FALSE, recursive = TRUE)
gset <- tryCatch(getGEO("GSE215011", destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE),
                  error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); NULL })
if (!is.null(gset)) {
  es <- gset[[1]]
  cat("dim:", dim(es), "platform:", annotation(es), "\n")
  print(colnames(pData(es)))
  cat("\ncharacteristics:\n")
  pd <- pData(es)
  for (cn in colnames(pd)) {
    if (grepl("respon|benefit|characteristics|title", cn, ignore.case = TRUE)) {
      cat("\n", cn, ":\n"); print(table(pd[[cn]], useNA = "always"))
    }
  }
  cat("\nsupplementary_file:\n"); print(unique(pd$supplementary_file))
}
gse_suppl <- tryCatch(getGEOSuppFiles("GSE215011", baseDir = DATA_DIR, makeDirectory = FALSE),
                       error = function(e) { cat("SUPPL ERROR:", conditionMessage(e), "\n"); NULL })
print(gse_suppl)
