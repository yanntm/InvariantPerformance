# comparisons.R: Who-beats-who matrices

library(dplyr)

who_beats_who <- function(df, metric, better = "lower", filter_name) {
  merged <- df %>%
    select(ID, Tool, all_of(metric)) %>%
    pivot_wider(names_from = Tool, values_from = all_of(metric), names_prefix = paste0(metric, "_"))
  tools <- setdiff(names(merged)[-1], "ID")  # All metric_Tool columns
  tools <- sub(paste0(metric, "_"), "", tools)
  
  type_matrix <- matrix(0, nrow = length(tools), ncol = length(tools), dimnames = list(tools, tools))
  equality_matrix <- type_matrix
  
  for (i in seq_along(tools)) {
    for (j in seq_along(tools)) {
      if (i != j) {
        col1 <- paste0(metric, "_", tools[i])
        col2 <- paste0(metric, "_", tools[j])
        wins <- sum(
          ifelse(better == "lower",
                 merged[[col1]] < merged[[col2]],
                 merged[[col1]] > merged[[col2]]),
          na.rm = TRUE
        )
        ties <- sum(merged[[col1]] == merged[[col2]], na.rm = TRUE)
        type_matrix[i, j] <- wins
        equality_matrix[i, j] <- ties
      }
    }
  }
  
  cat("Who Beats Who Matrix for", metric, "-", filter_name, "\n")
  print(type_matrix)
  cat("Equality Matrix for", metric, "-", filter_name, "\n")
  print(equality_matrix)
  write.csv(type_matrix, paste0(metric, "_matrix_", filter_name, ".csv"), row.names = TRUE)
  write.csv(equality_matrix, paste0(metric, "_equality_", filter_name, ".csv"), row.names = TRUE)
}