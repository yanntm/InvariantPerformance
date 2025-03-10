# data_prep.R: Data loading, cleaning, and filtering

library(dplyr)

# Helper function to generate rm commands and write to file
generate_rm_commands <- function(data, reason, output_file) {
  if (nrow(data) == 0) return(invisible(NULL))  # Skip if no data
  
  cat(sprintf("Found %d data points for %s. Writing rm commands to '%s'.\n", 
              nrow(data), reason, output_file))
  
  # Open file connection
  con <- file(output_file, "w")
  writeLines("#!/bin/bash", con)
  writeLines(sprintf("# Commands to remove files for %s", reason), con)
  
  for (i in seq_len(nrow(data))) {
    row <- data[i, ]
    model <- row$Model
    tool <- row$Tool
    exam <- tolower(row$Examination)
    folder <- paste0("logs_", exam)

    # Map Tool to file extension
    if (tool == "ItsTools") {
      extension <- ".its"
      flags <- ""
    } else if (tool == "tina") {
      extension <- ".tina"
      flags <- ""
    } else if (tool == "tina4ti2") {
      extension <- ".struct"
      flags <- ""
    } else if (tool == "GreatSPN") {
      extension <- ".gspn"
      flags <- ""
    } else if (grepl("^PetriSpot64", tool)) {
      extension <- ".petri64"
      flags <- sub("PetriSpot64_", "", tool)  # Extract flags (e.g., "loopL500")
      if (flags == "PetriSpot64") flags <- ""  # Handle plain "PetriSpot64"
    } else {
      stop(paste("Unknown tool:", tool))
    }

    # Construct rm command
    file_pattern <- paste0(folder, "/", model, ifelse(flags == "", "", "."), flags, extension, "*")
    writeLines(sprintf("rm %s", file_pattern), con)
  }
  
  close(con)
  system(sprintf("chmod +x %s", output_file))  # Make executable
}

# New function to generate rm commands for solution files when Status != "OK"
generate_rm_solution_files <- function(data, output_file) {
  not_ok_data <- data %>% filter(Status != "OK")
  if (nrow(not_ok_data) == 0) {
    cat("No runs with Status != 'OK' to generate solution file removal commands.\n")
    return(invisible(NULL))
  }
  
  cat(sprintf("Found %d runs with Status != 'OK'. Writing solution file removal commands to '%s'.\n", 
              nrow(not_ok_data), output_file))
  
  con <- file(output_file, "w")
  writeLines("#!/bin/bash", con)
  writeLines("# Commands to remove solution files for runs with Status != 'OK'", con)
  
  for (i in seq_len(nrow(not_ok_data))) {
    row <- not_ok_data[i, ]
    model <- row$Model
    tool <- row$Tool
    exam <- tolower(row$Examination)
    folder <- paste0("logs_", exam)

    # Map Tool to base file extension
    if (tool == "ItsTools") {
      extension <- ".its"
      flags <- ""
    } else if (tool == "tina") {
      extension <- ".tina"
      flags <- ""
    } else if (tool == "tina4ti2") {
      extension <- ".struct"
      flags <- ""
    } else if (tool == "GreatSPN") {
      extension <- ".gspn"
      flags <- ""
    } else if (grepl("^PetriSpot64", tool)) {
      extension <- ".petri64"
      flags <- sub("PetriSpot64_", "", tool)
      if (flags == "PetriSpot64") flags <- ""
    } else {
      stop(paste("Unknown tool:", tool))
    }

    # Construct solution file pattern
    sol_file <- paste0(folder, "/", model, ifelse(flags == "", "", "."), flags, extension, ".sol.gz")
    writeLines(sprintf("rm -f %s", sol_file), con)  # -f to avoid errors if file doesn't exist
  }
  
  close(con)
  system(sprintf("chmod +x %s", output_file))  # Make executable
}

load_and_clean_data <- function(file) {
  data <- read.csv(file, dec = ".", sep = ",", header = TRUE, stringsAsFactors = FALSE)
  data[data == -1] <- NA  # Replace -1 with NA
  data <- data[!grepl("COL", data$Model), ]  # Exclude COL models
  data$ID <- paste(data$Model, data$Examination, sep = "_")  # Add ID column

  # Check for duplicate ID-Tool pairs
  duplicates <- data %>%
    group_by(ID, Tool) %>%
    summarise(n = n(), .groups = "drop") %>%
    filter(n > 1)
  if (nrow(duplicates) > 0) {
    cat("Warning: Found", nrow(duplicates), "duplicate ID-Tool pairs in the data.\n")
    cat("Keeping only the first occurrence for each ID-Tool pair.\n")
    cat("Duplicate details saved to 'csv/duplicate_ID_Tool.csv'.\n")
    write.csv(duplicates, "csv/duplicate_ID_Tool.csv", row.names = FALSE)
    data <- data %>%
      group_by(ID, Tool) %>%
      slice(1) %>%  # Keep first occurrence
      ungroup()
  } else {
    cat("No duplicate ID-Tool pairs detected.\n")
  }

  # Check for Status == "OK" with missing Sol* metrics
  sol_cols <- grep("^Sol", names(data), value = TRUE)
  missing_solutions_ok <- data %>%
    filter(Status == "OK" & rowSums(across(all_of(sol_cols), is.na)) > 0) %>%
    select(Model, Tool, Examination, Status, all_of(sol_cols))
  if (nrow(missing_solutions_ok) > 0) {
    cat("Warning: Found", nrow(missing_solutions_ok), "data points with Status 'OK' but missing Sol* metrics (originally -1).\n")
    cat("These runs reported success but lack solution data; Sol* metrics remain NA.\n")
    cat("See 'csv/missingSolutions_OK.csv' for details.\n")
    dir.create("csv", showWarnings = FALSE)
    write.csv(missing_solutions_ok, "csv/missingSolutions_OK.csv", row.names = FALSE)
  } else {
    cat("No Status 'OK' runs with missing Sol* metrics detected.\n")
  }

  # Check for Status == "OK" with missing Time or Mem
  missing_time_mem_ok <- data %>%
    filter(Status == "OK" & (is.na(Time) | is.na(Mem))) %>%
    select(Model, Tool, Examination, Status, Time, Mem)
  if (nrow(missing_time_mem_ok) > 0) {
    cat("Warning: Found", nrow(missing_time_mem_ok), "data points with Status 'OK' but missing Time or Mem (originally -1).\n")
    cat("These runs reported success but lack performance metrics; Time and Mem remain NA.\n")
    cat("See 'csv/missingTimeMem_OK.csv' for details.\n")
    dir.create("csv", showWarnings = FALSE)
    write.csv(missing_time_mem_ok, "csv/missingTimeMem_OK.csv", row.names = FALSE)
    generate_rm_commands(missing_time_mem_ok, "missing Time/Mem runs", "rmTimeIssues.sh")
  } else {
    cat("No Status 'OK' runs with missing Time or Mem detected.\n")
  }

  # Check for Status != "OK" with missing Time or Mem, excluding TO with NA Mem
  missing_time_mem_not_ok <- data %>%
    filter(Status != "OK" &
           !((Status == "TO" & is.na(Mem) & !is.na(Time))) &  # Exclude TO with NA Mem and valid Time
           (is.na(Time) | is.na(Mem))) %>%
    select(Model, Tool, Examination, Status, Time, Mem)
  if (nrow(missing_time_mem_not_ok) > 0) {
    cat("Warning: Found", nrow(missing_time_mem_not_ok), "data points with Status != 'OK' but missing Time or Mem (originally -1), excluding expected TO cases with NA Mem.\n")
    cat("These runs failed but lack performance metrics; Time and Mem remain NA.\n")
    cat("See 'csv/missingTimeMem_not_OK.csv' for details.\n")
    dir.create("csv", showWarnings = FALSE)
    write.csv(missing_time_mem_not_ok, "csv/missingTimeMem_not_OK.csv", row.names = FALSE)
  } else {
    cat("No Status != 'OK' runs with missing Time or Mem detected (excluding TO with NA Mem).\n")
  }

  # Sanity check and preprocess Sol* metrics for non-OK runs
  problematic_rows <- data %>%
    filter(Status != "OK" & rowSums(across(all_of(sol_cols), ~!is.na(.) & . != 0)) > 0) %>%
    select(Model, Tool, Examination, Status, all_of(sol_cols))
  if (nrow(problematic_rows) > 0) {
    cat("Warning: Discarding", nrow(problematic_rows), "data points with non-zero Sol* values for incomplete or unsuccessful runs (Status != 'OK').\n")
    cat("These solutions are considered unreliable (e.g., timeouts during printing, memory overflows, or 4ti2 crashes in tina) and have been set to NA.\n")
    cat("See 'csv/incompleteSolutions.csv' for details.\n")
    dir.create("csv", showWarnings = FALSE)
    write.csv(problematic_rows, "csv/incompleteSolutions.csv", row.names = FALSE)
    generate_rm_commands(problematic_rows, "runs with partial solutions", "rmIncompleteSol.sh")
  } else {
    cat("No incomplete or unsuccessful runs with non-zero Sol* values detected.\n")
  }

  # Generate commands to remove solution files for Status != "OK"
  generate_rm_solution_files(data, "rmSolNotOk.sh")

  # Set Sol* metrics to NA when Status != "OK"
  data <- data %>%
    mutate(across(starts_with("Sol"), ~ifelse(Status == "OK", ., NA)))

  return(data)
}

