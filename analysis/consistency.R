# consistency.R: Data quality checks for invar.csv

library(dplyr)

check_data_quality <- function(data) {
  # Ensure key columns are character, not factors
  data <- data %>% mutate(across(c(Model, Tool, Examination), as.character))
  
  # Basic stats
  cat("Total data points:", nrow(data), "\n")
  cat("Number of unique tools:", length(unique(data$Tool)), "\n")
  cat("Number of unique models:", length(unique(data$Model)), "\n")
  
  # Check for non-numeric Time values
  cat("Checking for non-numeric Time values:\n")
  non_numeric_time <- data[!is.na(data$Time) & !grepl("^-?[0-9]+$", data$Time), ]
  if (nrow(non_numeric_time) > 0) {
    print(non_numeric_time[, c("Model", "Tool", "Examination", "Time")])
  } else {
    cat("All Time values appear numeric.\n")
  }
  
  # Check for non-numeric Mem values
  cat("Checking for non-numeric Mem values:\n")
  non_numeric_mem <- data[!is.na(data$Mem) & !grepl("^-?[0-9]+$", data$Mem), ]
  if (nrow(non_numeric_mem) > 0) {
    print(non_numeric_mem[, c("Model", "Tool", "Examination", "Mem")])
  } else {
    cat("All Mem values appear numeric.\n")
  }
  
  # Build the complete cross-product for triplets (using real names)
  expected_triplets <- expand.grid(
    Model = unique(data$Model),
    Tool = unique(data$Tool),
    Examination = unique(data$Examination),
    stringsAsFactors = FALSE
  )
  
  actual_triplets <- data %>% select(Model, Tool, Examination)
  missing_triplets <- anti_join(expected_triplets, actual_triplets, by = c("Model", "Tool", "Examination"))
  
  # Identify which Tool/Examination pairs actually appear in the data.
  actual_pairs <- data %>% distinct(Tool, Examination)
  
  # Partition missing triplets:
  #   1. For pairs that exist in the data, report missing models.
  missing_triplets_existing_pairs <- missing_triplets %>%
    semi_join(actual_pairs, by = c("Tool", "Examination"))
  
  #   2. For pairs that never occur, report a concise message.
  missing_triplets_non_existing_pairs <- missing_triplets %>%
    anti_join(actual_pairs, by = c("Tool", "Examination"))
  
  if (nrow(missing_triplets_non_existing_pairs) > 0) {
    non_participating_pairs <- missing_triplets_non_existing_pairs %>% distinct(Tool, Examination)
    cat("Tool/Examination pairs with no participation detected:\n")
    for (i in 1:nrow(non_participating_pairs)) {
      cat("Tool", non_participating_pairs$Tool[i], "does not participate in", non_participating_pairs$Examination[i], "\n")
    }
  }
  
  if (nrow(missing_triplets_existing_pairs) > 0) {
    cat("Missing triplets for participating Tool/Examination pairs:\n")
    print(missing_triplets_existing_pairs)
    cat("Number of missing triplets:", nrow(missing_triplets_existing_pairs), "\n")
  } else {
    cat("All expected Tool/Examination/Model triplets present for participating pairs.\n")
  }
}
