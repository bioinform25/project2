# In silico check: does HSF2 appear as a predicted upstream regulator of the
# NET-panel genes via ChEA3 (TF enrichment across ChIP-seq + co-expression +
# literature libraries)? Queried in the "reverse" direction from Step 1's
# original plan (which asked "what does HSF2 target") because ChEA3's API takes
# a gene set and ranks candidate upstream TFs - so the genes our cross-cohort
# analysis (08_cross_cohort_gene_consistency.R) flagged as robustly, consistently
# HSF2-associated are submitted as the query, and HSF2's rank/evidence is read off.
#
# Three query sets, reflecting what the data actually showed:
#  (a) NET_core_consistent: PADI4, ELANE, MPO, CAMP, DEFA4 - the 5 genes that were
#      same-direction (negative) across all 4 cohorts in 08_cross_cohort...R
#  (b) NET_organ_divergent: LTF, NCF2, ITGAM, LCN2 - genes whose sign flipped
#      between liver and lung (tests whether HSF2 shows up for these too, or
#      only for the consistent set - a specificity check on the TF-level claim)
#  (c) NET_core_only: PADI4, ELANE, MPO - the original pre-specified panel alone

suppressPackageStartupMessages(library(jsonlite))
OUT_DIR <- "C:/Users/SAMSUNG/Desktop/project2/results"

chea3_query <- function(genes, query_name) {
  res <- httr::POST(
    url = "https://maayanlab.cloud/chea3/api/enrich/",
    body = list(query_name = query_name, gene_set = as.list(genes)),
    encode = "json", httr::timeout(30)
  )
  fromJSON(httr::content(res, as = "text", encoding = "UTF-8"), simplifyVector = TRUE)
}

# Different ChEA3 sub-libraries return different column sets (the two "Integrated"
# tables have Score; the per-library tables have Intersect/FET p-value/FDR/Odds Ratio
# instead) - extract a common, always-present subset per row rather than assuming a
# fixed schema across all 8 libraries.
find_hsf2 <- function(chea3_res, query_name, n_libs) {
  out <- list()
  for (lib in names(chea3_res)) {
    df <- chea3_res[[lib]]
    hit <- df[df$TF == "HSF2", ]
    if (nrow(hit) == 1) {
      out[[lib]] <- data.frame(
        query = query_name, library = lib,
        rank = hit$Rank[[1]], total_TFs_ranked = nrow(df),
        intersect_n = if ("Intersect" %in% names(hit)) hit$Intersect[[1]] else NA,
        FDR = if ("FDR" %in% names(hit)) hit$FDR[[1]] else NA,
        odds_ratio = if ("Odds Ratio" %in% names(hit)) hit$`Odds Ratio`[[1]] else NA,
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(out) == 0) return(data.frame(query = query_name, library = "NOT RETURNED in any of the queried libraries",
                                           rank = NA, total_TFs_ranked = NA, intersect_n = NA, FDR = NA, odds_ratio = NA))
  do.call(rbind, out)
}

queries <- list(
  NET_core_consistent = c("PADI4", "ELANE", "MPO", "CAMP", "DEFA4"),
  NET_organ_divergent = c("LTF", "NCF2", "ITGAM", "LCN2"),
  NET_core_only        = c("PADI4", "ELANE", "MPO")
)

all_results <- list()
for (qn in names(queries)) {
  cat("=== Querying ChEA3:", qn, "(", paste(queries[[qn]], collapse=","), ") ===\n")
  res <- chea3_query(queries[[qn]], qn)
  hsf2_hit <- find_hsf2(res, qn, length(res))
  print(hsf2_hit, row.names = FALSE)
  all_results[[qn]] <- hsf2_hit
  Sys.sleep(1)
}

final <- do.call(rbind, all_results)
write.csv(final, file.path(OUT_DIR, "CHEA3_HSF2_enrichment_results.csv"), row.names = FALSE)
cat("\n=== FULL SUMMARY: HSF2 rank across all queries/libraries ===\n")
print(final, row.names = FALSE)
