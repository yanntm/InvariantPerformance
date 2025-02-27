# stats.R: Summary statistics and mean tables

library(dplyr)

numeric_cols <- function(df) names(df)[sapply(df, is.numeric)]

get_tool_stats <- function(df, filter_name) {
  # Use narrow data directly
  stats <- df %>%
    group_by(Tool) %>%
    summarise(
      Mean_Time = mean(Time, na.rm = TRUE),
      Mean_Mem = mean(Mem, na.rm = TRUE),
      Total_Runs = n(),
      .groups = "drop"
    )
  
  status_counts <- df %>%
    group_by(Tool, Status) %>%
    summarise(n = n(), .groups = "drop") %>%
    pivot_wider(names_from = Status, values_from = n, values_fill = 0, names_prefix = "Status_")
  
  complete_stats <- stats %>%
    left_join(status_counts, by = "Tool") %>%
    mutate(
      Failures = Total_Runs - if_else(is.na(Status_OK), 0L, as.integer(Status_OK)),
      Status_NA = if ("Status_NA" %in% names(.)) {
        if_else(is.na(Status_NA), 0L, as.integer(Status_NA))
      } else {
        0L  # If Status_NA column doesn’t exist, assume 0 missing runs
      }
    ) %>%
    select(Tool, Mean_Time, Mean_Mem, Total_Runs, Status_OK, Failures, Status_NA, everything())
  
  cat("Tool Stats for", filter_name, "\n")
  print(complete_stats)
  write.csv(complete_stats, paste0("tool_stats_", filter_name, ".csv"), row.names = FALSE)
}

print_mean <- function(df, filter_name) {
  means <- df %>%
    group_by(Tool) %>%
    summarise(across(where(is.numeric), mean, na.rm = TRUE), .groups = "drop")
  cat("Mean Values for", filter_name, "\n")
  print(means)
  write.csv(means, paste0("mean_", filter_name, ".csv"), row.names = FALSE)
}