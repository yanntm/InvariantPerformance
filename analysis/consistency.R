# consistency.R: Data quality checks for invar.csv

library(dplyr)

check_data_quality <- function(data) {
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

  # Check triplet completeness
  expected_triplets <- expand.grid(
    Model = unique(data$Model),
    Tool = unique(data$Tool),
    Examination = unique(data$Examination)
  )
  actual_triplets <- data %>% select(Model, Tool, Examination)
  missing_triplets <- anti_join(expected_triplets, actual_triplets, by = c("Model", "Tool", "Examination"))
  if (nrow(missing_triplets) > 0) {
    cat("Missing triplets detected:\n")
    print(missing_triplets)
    cat("Number of missing triplets:", nrow(missing_triplets), "\n")
  } else {
    cat("All expected Tool/Examination/Model triplets present.\n")
  }
}