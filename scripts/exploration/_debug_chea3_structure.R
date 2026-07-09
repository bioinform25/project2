suppressPackageStartupMessages(library(jsonlite))
res <- fromJSON(readLines("C:/Users/SAMSUNG/Desktop/project2/results/exploration/chea3_raw_response.json"), simplifyVector = TRUE)
cat("Libraries:\n"); print(names(res))
for (lib in names(res)) {
  df <- res[[lib]]
  cat("\n---", lib, "--- colnames:", paste(colnames(df), collapse = ","), " nrow:", nrow(df), "\n")
  hit <- df[df$TF == "HSF2", ]
  cat("HSF2 rows:", nrow(hit), "\n")
  if (nrow(hit) > 0) print(hit)
}
