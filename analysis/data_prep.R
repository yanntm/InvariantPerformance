# data_prep.R: Data loading, cleaning, and filtering

library(dplyr)

load_and_clean_data <- function(file) {
  data <- read.csv(file, dec = ".", sep = ",", header = TRUE, stringsAsFactors = FALSE)
  data[data == -1] <- NA  # Replace -1 with NA
  data <- data[!grepl("COL", data$Model), ]  # Exclude COL models
  data$ID <- paste(data$Model, data$Examination, sep = "_")  # Add ID column
  
  # Sanity check and preprocess Sol* metrics
  sol_cols <- grep("^Sol", names(data), value = TRUE)
  # Find rows where Status != "OK" and any Sol* is non-zero
  problematic_rows <- data %>%
    filter(Status != "OK" & rowSums(across(all_of(sol_cols), ~!is.na(.) & . != 0)) > 0) %>%
    select(Model, Tool, Examination, Status, all_of(sol_cols))
  
  if (nrow(problematic_rows) > 0) {
    cat("Warning: Discarding", nrow(problematic_rows), "data points with non-zero Sol* values for incomplete or unsuccessful runs (Status != 'OK').\n")
    cat("These solutions are considered unreliable (e.g., timeouts during printing, memory overflows, or 4ti2 crashes in tina) and have been set to NA.\n")
    cat("See 'csv/incompleteSolutions.csv' for details.\n")
    print(problematic_rows)
    # Write problematic rows to CSV
    dir.create("csv", showWarnings = FALSE)
    write.csv(problematic_rows, "csv/incompleteSolutions.csv", row.names = FALSE)
  } else {
    cat("No incomplete or unsuccessful runs with non-zero Sol* values detected.\n")
  }
  
  # Set Sol* metrics to NA when Status != "OK"
  data <- data %>%
    mutate(across(starts_with("Sol"), ~ifelse(Status == "OK", ., NA)))
  
  return(data)
}

filter_data <- function(data, condition) {
  if (isTRUE(condition)) return(data)
  subset(data, eval(condition))
}