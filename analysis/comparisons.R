# comparisons.R: Who-beats-who matrices

library(dplyr)

who_beats_who <- function(df, metric, better = "lower", filter_name, na_loses = FALSE) {
  # Pivot data once with all tools
  merged <- df %>%
    select(ID, Tool, all_of(metric)) %>%
    pivot_wider(names_from = Tool, values_from = all_of(metric))
  
  tools <- setdiff(names(merged), "ID")
  type_matrix <- matrix(0, nrow = length(tools), ncol = length(tools), dimnames = list(tools, tools))
  
  # Compute wins
  for (i in seq_along(tools)) {
    for (j in seq_along(tools)) {
      if (i != j) {
        col1 <- tools[i]
        col2 <- tools[j]
        if (better == "lower") {
          type_matrix[i, j] <- sum(
            ifelse(na_loses & is.na(merged[[col2]]), TRUE,
                   !is.na(merged[[col1]]) & (is.na(merged[[col2]]) | merged[[col1]] < merged[[col2]])),
            na.rm = TRUE
          )
        } else {
          type_matrix[i, j] <- sum(
            ifelse(na_loses & is.na(merged[[col2]]), TRUE,
                   !is.na(merged[[col1]]) & (is.na(merged[[col2]]) | merged[[col1]] > merged[[col2]])),
            na.rm = TRUE
          )
        }
      }
    }
  }
  
  cat("Who Beats Who Matrix for", metric, "-", filter_name, "\n")
  cat("Row beats column; smaller is better\n")
  print(type_matrix)
  write.csv(type_matrix, paste0("csv/", metric, "_matrix_", filter_name, ".csv"), row.names = TRUE)
}