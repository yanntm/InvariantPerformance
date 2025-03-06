# main.R: Main workflow orchestration

library(dplyr)
library(tidyr)
library(ggplot2)
library(gridExtra)
library(grid)

options(width = 1000)  # Improve console output width

source("consistency.R")
source("data_prep.R")
source("stats.R")
source("plots.R")
source("comparisons.R")
source("utils.R")

# Command-line args
args <- commandArgs(trailingOnly = TRUE)
csv_file <- if (length(args) > 0) args[1] else "../invar.csv"
tools_arg <- if (length(args) > 1) args[2] else ""

# Load and clean data
data <- load_and_clean_data(csv_file)

# Apply tool filter
if (tools_arg != "") {
  tools_filter <- trimws(unlist(strsplit(tools_arg, ",")))
  data <- data %>% filter(Tool %in% tools_filter)
}

# Check data quality
check_data_quality(data)

# Create output directories
dir.create("pdf", showWarnings = FALSE)
dir.create("csv", showWarnings = FALSE)

# Plot model descriptions
plot_model_descriptions(data)

# Define filters
filters <- list(
  "P_Flows" = quote(Examination == "PFLOWS"),
  "T_Flows" = quote(Examination == "TFLOWS"),
  "P_Semiflows" = quote(Examination == "PSEMIFLOWS"),
  "T_Semiflows" = quote(Examination == "TSEMIFLOWS")
)
# Commented examples for future use:
#  "All_Examinations" = TRUE,
#  "P_Invariants" = quote(Examination %in% c("PSEMIFLOWS", "PFLOWS")),
#  "Small_Models" = quote(CardP + CardT < 5000)

# Metrics to analyze (SolXX only)
metrics <- c("SolSizeKB", "SolSize", "SolPosSize", "SolMaxCoeff", "SolSumCoeff", "SolNbCoeff")

# Helper function: returns TRUE if two PetriSpot64 tool names differ by exactly one flag.
differ_by_one_flag <- function(tool1, tool2) {
  tokens1 <- unlist(strsplit(tool1, "_"))
  tokens2 <- unlist(strsplit(tool2, "_"))
  
  # Only apply flag-difference check if the base (first token) is identical.
  if (tokens1[1] != tokens2[1]) return(FALSE)
  
  flags1 <- tokens1[-1]
  flags2 <- tokens2[-1]
  
  # If lengths differ by more than 1, then they differ by more than one flag.
  if (abs(length(flags1) - length(flags2)) > 1) return(FALSE)
  
  if (length(flags1) == length(flags2)) {
    diff_count <- sum(flags1 != flags2)
    return(diff_count == 1)
  } else {
    # One tool has one extra flag; check if removing one flag from the longer list makes them equal.
    if (length(flags1) > length(flags2)) {
      longer <- flags1; shorter <- flags2
    } else {
      longer <- flags2; shorter <- flags1
    }
    for (i in seq_along(longer)) {
      candidate <- longer[-i]
      if (all(candidate == shorter)) {
        return(TRUE)
      }
    }
    return(FALSE)
  }
}

# Process each Examination (existing analysis)
for (exam in unique(data$Examination)) {
  exam_data <- data %>% filter(Examination == exam)
  wide_data <- exam_data %>%
    pivot_wider(
      id_cols = "Model",
      names_from = Tool,
      values_from = c("Time", "Mem", "Status", "CardP", "CardT", "CardA", "NbPInv", "NbTInv", "Examination"),
      values_fn = list(
        Time = first, Mem = first, Status = first, 
        CardP = first, CardT = first, CardA = first, 
        NbPInv = first, NbTInv = first, Examination = first
      ),
      values_fill = list(Status = "NA")
    ) %>%
    mutate(across(where(is.numeric), ~replace_na(., 0)))
  
  tools <- unique(exam_data$Tool)
  if (exists("tools_filter")) tools <- intersect(tools, tools_filter)
  
  if (length(tools) < 2) {
    cat("Examination", exam, "has less than two tools. Skipping comparisons.\n")
    next
  }
  
  get_tool_stats(exam_data, exam)
  
  combinations <- combn(tools, 2, simplify = FALSE)
  for (combo in combinations) {
    tool1 <- combo[1]
    tool2 <- combo[2]
    # For PetriSpot64 variants, only compare if they differ by exactly one flag.
    if (grepl("^PetriSpot64", tool1) && grepl("^PetriSpot64", tool2)) {
      if (!differ_by_one_flag(tool1, tool2)) next
    }
    plot_comparisons(wide_data, tool1, tool2, exam)
  }
}

# New overviews across filters
for (filter_name in names(filters)) {
  filtered_data <- filter_data(data, filters[[filter_name]])
  print_mean(filtered_data, filter_name)
  plot_numerics(filtered_data, filter_name)
  for (metric in metrics) {
    who_beats_who(filtered_data, metric, "lower", filter_name, na_loses = FALSE)  # Smaller is better
  }
}
