library(dplyr)
library(tidyr)
library(purrr)
library(ggplot2)
library(grid)
library(gridExtra)
library(kableExtra)

options(width = 1000)

args <- commandArgs(trailingOnly = TRUE)
csv_file <- if (length(args) > 0) args[1] else "invar.csv"
tools_arg <- if (length(args) > 1) args[2] else ""

data <- read.csv(csv_file, dec = ".", sep = ",", header = TRUE, stringsAsFactors = FALSE)

# Check for non-numeric Time and Mem
cat("Checking raw data for non-numeric Time values:\n")
non_numeric_time <- data[!is.na(data$Time) & !grepl("^-?[0-9]+$", data$Time), ]
if (nrow(non_numeric_time) > 0) {
  print(non_numeric_time[, c("Model", "Tool", "Examination", "Time")])
} else {
  cat("All Time values appear numeric.\n")
}

cat("Checking raw data for non-numeric Mem values:\n")
non_numeric_mem <- data[!is.na(data$Mem) & !grepl("^-?[0-9]+$", data$Mem), ]
if (nrow(non_numeric_mem) > 0) {
  print(non_numeric_mem[, c("Model", "Tool", "Examination", "Mem")])
} else {
  cat("All Mem values appear numeric.\n")
}

# Check triplet completeness
expected_models <- unique(data$Model)
expected_tools <- unique(data$Tool)
expected_exams <- unique(data$Examination)
expected_triplets <- expand.grid(Model = expected_models, Tool = expected_tools, Examination = expected_exams)
actual_triplets <- data %>% select(Model, Tool, Examination)
missing_triplets <- anti_join(expected_triplets, actual_triplets, by = c("Model", "Tool", "Examination"))
if (nrow(missing_triplets) > 0) {
  cat("Missing triplets detected in invar.csv:\n")
  print(missing_triplets)
  cat("Number of missing triplets:", nrow(missing_triplets), "\n")
} else {
  cat("All expected Tool/Examination/Model triplets present.\n")
}

data <- data %>% mutate(across(where(is.numeric), ~na_if(., -1)))
data <- data %>% filter(!grepl("COL", Model))
if (tools_arg != "") {
  tools_filter <- trimws(unlist(strsplit(tools_arg, ",")))
  data <- data %>% filter(Tool %in% tools_filter)
}

get_tool_stats <- function(tool, df, exam_data) {
  mean_time_col <- paste("Time", tool, sep = "_")
  mean_mem_col <- paste("Mem", tool, sep = "_")
  status_col <- paste("Status", tool, sep = "_")
  
  if (!mean_time_col %in% names(df)) {
    cat("Column", mean_time_col, "not found for tool", tool, "\n")
    return(NULL)
  }
  if (!mean_mem_col %in% names(df)) {
    cat("Column", mean_mem_col, "not found for tool", tool, "\n")
    return(NULL)
  }
  
  total_runs <- exam_data %>% filter(Tool == tool) %>% nrow()
  expected_runs <- length(expected_models)  # Global expected models
  missing_runs <- expected_runs - total_runs
  
  stats <- df %>%
    summarise(
      Tool = tool,
      Mean_Time = mean(get(mean_time_col), na.rm = TRUE),
      Mean_Mem = mean(get(mean_mem_col), na.rm = TRUE),
      Total_Runs = total_runs,
      .groups = 'drop'
    )
  
  status_counts <- df %>%
    group_by(!!rlang::sym(status_col)) %>%
    summarise(n = n(), .groups = 'drop') %>%
    pivot_wider(
      names_from = !!rlang::sym(status_col), 
      values_from = n, 
      values_fill = list(n = 0)
    ) %>%
    rename_with(~ paste("Status", ., sep = "_"), everything())
  
  complete_stats <- bind_cols(stats, status_counts) %>%
    mutate(Status_NA = missing_runs,
           Failures = Total_Runs - Status_OK,
           Failures = if_else(is.na(Failures), 0L, as.integer(Failures))) %>%
    select(Tool, Mean_Time, Mean_Mem, Total_Runs, Status_OK, Failures, Status_NA, everything())
  
  return(complete_stats)
}

plot_comparisons <- function(df, tool1, tool2) {
  status_col1 <- paste("Status", tool1, sep = "_")
  status_col2 <- paste("Status", tool2, sep = "_")
  
  fperf <- df %>%
    filter(!is.na(get(paste("Time", tool1, sep = "_"))) & 
           !is.na(get(paste("Time", tool2, sep = "_"))) &
           get(status_col1) != "NA" & 
           get(status_col2) != "NA") %>%
    mutate(
      RepTime_1 = ifelse(get(status_col1) != "OK", 120000, get(paste("Time", tool1, sep = "_"))),
      RepTime_2 = ifelse(get(status_col2) != "OK", 120000, get(paste("Time", tool2, sep = "_"))),
      Mem_1 = ifelse(get(status_col1) != "OK", 16000000, get(paste("Mem", tool1, sep = "_"))),
      Mem_2 = ifelse(get(status_col2) != "OK", 16000000, get(paste("Mem", tool2, sep = "_"))),
      Verdict_Color = case_when(
        get(status_col1) == "OK" & get(status_col2) != "OK" ~ paste("Only", tool1, "solves"),
        get(status_col2) == "OK" & get(status_col1) != "OK" ~ paste("Only", tool2, "solves"),
        get(status_col1) == "OK" & get(status_col2) == "OK" ~ "Both tools solve",
        TRUE ~ "Both tools fail"
      )
    )
  
  verdict_counts <- fperf %>%
    count(Verdict_Color) %>%
    mutate(Label = paste(Verdict_Color, " (", n, ")", sep = ""))
  total_points <- nrow(fperf)
  legend_title <- paste("Outcome (", total_points, ")", sep = "")
  fperf <- fperf %>%
    left_join(verdict_counts %>% select(Verdict_Color, Label), by = "Verdict_Color") %>%
    mutate(Verdict_Color = Label)
  
  time_plot <- ggplot(fperf, aes(x = RepTime_1, y = RepTime_2, color = Verdict_Color)) +
    geom_point() +
    scale_x_continuous(trans = 'log10', 
                       breaks = c(10, 100, 1000, 10000, 60000, 120000),
                       labels = c("0.01s", "0.1s", "1s", "10s", "1min", "2min")) +
    scale_y_continuous(trans = 'log10', 
                       breaks = c(10, 100, 1000, 10000, 60000, 120000),
                       labels = c("0.01s", "0.1s", "1s", "10s", "1min", "2min")) +
    geom_abline(intercept = 0, slope = 1) +
    scale_color_manual(values = c("orange", "blue", "green", "red")) +
    guides(color = guide_legend(title = legend_title)) +
    xlab(paste("Time for", tool1)) +
    ylab(paste("Time for", tool2)) +
    ggtitle(paste("Run time comparison between", tool1, "and", tool2))
  
  memory_plot <- ggplot(fperf, aes(x = Mem_1, y = Mem_2, color = Verdict_Color)) +
    geom_point() +
    scale_x_continuous(trans = 'log10', 
                       breaks = c(10000, 100000, 1000000, 3000000, 10000000, 16000000),
                       labels = c("10MB", "100MB", "1GB", "3GB", "10GB", "16GB")) +
    scale_y_continuous(trans = 'log10', 
                       breaks = c(10000, 100000, 1000000, 3000000, 10000000, 16000000),
                       labels = c("10MB", "100MB", "1GB", "3GB", "10GB", "16GB")) +
    geom_abline(intercept = 0, slope = 1) +
    scale_color_manual(values = c("orange", "blue", "green", "red")) +
    guides(color = guide_legend(title = legend_title)) +
    xlab(paste("Memory for", tool1)) +
    ylab(paste("Memory for", tool2)) +
    ggtitle(paste("Memory usage comparison between", tool1, "and", tool2))
  
  return(list(Time_Comparison = time_plot, Memory_Comparison = memory_plot))
}

examinations <- unique(data$Examination)

pdf("Tool_Comparisons.pdf", paper = "a4")
for (exam in examinations) {
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
  if (exists("tools_filter")) {
    tools <- intersect(tools, tools_filter)
  }
  
  if (length(tools) < 2) {
    cat("Examination", exam, "has less than two tools. Skipping comparisons.\n")
    next
  }
  
  tool_stats <- map_df(tools, ~get_tool_stats(.x, wide_data, exam_data))
  tool_stats <- tool_stats %>% mutate(across(everything(), ~replace_na(., 0)))
  cat("Examination:", exam, "\n")
  print(tool_stats)
  
  # Generate LaTeX table file with dynamic column names
  tex_file <- paste0("table_", exam, ".tex")
  col_names <- names(tool_stats) %>%
    sub("Mean_Time", "Mean Time (ms)", .) %>%
    sub("Mean_Mem", "Mean Mem (KB)", .) %>%
    sub("Total_Runs", "Total Runs", .) %>%
    sub("Status_", "", .)
  kable(tool_stats, "latex", booktabs = TRUE,
        caption = paste("Tool Statistics for", exam),
        col.names = col_names) %>%
    save_kable(tex_file)
  
  combinations <- combn(tools, 2, simplify = FALSE)
  for (combo in combinations) {
    tool1 <- combo[1]
    tool2 <- combo[2]
    plots <- plot_comparisons(wide_data, tool1, tool2)
    
    grid.arrange(
      plots$Time_Comparison, 
      plots$Memory_Comparison, 
      ncol = 1,
      top = textGrob(paste("Examination:", exam, "- Comparison:", tool1, "vs", tool2), 
                     gp = gpar(fontsize = 14, fontface = "bold"))
    )
  }
}
dev.off()

