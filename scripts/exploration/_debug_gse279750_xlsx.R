suppressPackageStartupMessages(library(readxl))
f <- "C:/Users/SAMSUNG/Desktop/project2/data/GSE279750/extracted/GSM8579621_NR1.R.xlsx"
sheets <- excel_sheets(f)
cat("sheets:", paste(sheets, collapse=", "), "\n")
d <- read_excel(f, sheet = sheets[1])
cat("dim:", dim(d), "\n")
print(head(d, 5))
cat("colnames:", paste(colnames(d), collapse=", "), "\n")
