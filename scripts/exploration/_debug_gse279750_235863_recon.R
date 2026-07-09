suppressPackageStartupMessages({library(GEOquery); library(Biobase)})

check_gse <- function(acc) {
  cat("\n\n############ ", acc, " ############\n")
  DATA_DIR <- file.path("C:/Users/SAMSUNG/Desktop/project2/data", acc)
  dir.create(DATA_DIR, showWarnings = FALSE, recursive = TRUE)
  gset <- tryCatch(getGEO(acc, destdir = DATA_DIR, GSEMatrix = TRUE, AnnotGPL = TRUE),
                    error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); NULL })
  if (!is.null(gset)) {
    for (i in seq_along(gset)) {
      es <- gset[[i]]
      cat("--- gset[[", i, "]] dim:", dim(es), "platform:", annotation(es), "---\n")
      pd <- pData(es)
      print(colnames(pd))
      for (cn in colnames(pd)) {
        if (grepl("respon|benefit|title|group|treat", cn, ignore.case = TRUE)) {
          cat("\n", cn, ":\n"); print(table(pd[[cn]], useNA = "always"))
        }
      }
      cat("supplementary_file:\n"); print(unique(pd$supplementary_file)[1:3])
    }
  }
  suppl <- tryCatch(getGEOSuppFiles(acc, baseDir = DATA_DIR, makeDirectory = FALSE),
                     error = function(e) { cat("SUPPL ERROR:", conditionMessage(e), "\n"); NULL })
  print(suppl)
}

check_gse("GSE279750")
check_gse("GSE235863")
