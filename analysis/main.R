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
csv_file <- if (length(args) > 0) args[1] else "invar.csv"
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

# Metrics to analyze
metrics <- c("SolSizeKB", "SolSize", "SolPosSize", "SolMaxCoeff", "SolSumCoeff", "SolNbCoeff", "Time")

# Process each Examination (existing analysis)
pdf("Tool_Comparisons.pdf", paper = "a4", width = 20, height = 14)
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
    plot_comparisons(wide_data, tool1, tool2, exam)
  }
}
dev.off()

# New overviews across filters
for (filter_name in names(filters)) {
  filtered_data <- filter_data(data, filters[[filter_name]])
  print_mean(filtered_data, filter_name)
  plot_numerics(filtered_data, filter_name)
  for (metric in metrics) {
    better <- if (metric == "Time") "lower" else "higher"  # Adjust as needed
    who_beats_who(filtered_data, metric, better, filter_name, na_loses = FALSE)  # Flag for NA handling
  }
}

