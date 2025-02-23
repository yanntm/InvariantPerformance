library(dplyr)
library(tidyr)
library(purrr)
library(ggplot2)
library(grid)
library(gridExtra)


options(width = 1000)  # or any sufficiently large number

# Accept command line arguments: CSV file and optional comma-separated tools list
args <- commandArgs(trailingOnly = TRUE)
csv_file <- if (length(args) > 0) args[1] else "invar.csv"
tools_arg <- if (length(args) > 1) args[2] else ""

# Load data
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

# Convert any -1 (which is invalid) to NA in numeric columns
data <- data %>% mutate(across(where(is.numeric), ~na_if(., -1)))

# Filter out models containing "COL"
data <- data %>% filter(!grepl("COL", Model))

# If a tools list is provided, filter data accordingly
if (tools_arg != "") {
  tools_filter <- trimws(unlist(strsplit(tools_arg, ",")))
  data <- data %>% filter(Tool %in% tools_filter)
}

get_tool_stats <- function(tool, df) {
  mean_time_col <- paste("Time", tool, sep = "_")
  mean_mem_col  <- paste("Mem", tool, sep = "_")
  status_col    <- paste("Status", tool, sep = "_")
  
  # Debug: Check if columns exist and their contents
  if (!mean_time_col %in% names(df)) {
    cat("Column", mean_time_col, "not found in data frame for tool", tool, "\n")
    return(NULL)
  }
  if (!mean_mem_col %in% names(df)) {
    cat("Column", mean_mem_col, "not found in data frame for tool", tool, "\n")
    return(NULL)
  }
  time_data <- df[[mean_time_col]]
  cat("Tool:", tool, "Time column sample:", head(time_data), "Class:", class(time_data), "\n")
  
  stats <- df %>%
    summarise(
      Tool = tool,
      Mean_Time = mean(get(mean_time_col), na.rm = TRUE),
      Mean_Mem  = mean(get(mean_mem_col), na.rm = TRUE),
      Total_Runs = n(),
      .groups = 'drop'
    )
  
  stats <- df %>%
    summarise(
      Tool = tool,
      Mean_Time = mean(get(mean_time_col), na.rm = TRUE),
      Mean_Mem  = mean(get(mean_mem_col), na.rm = TRUE),
      Total_Runs = n(),
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
  
  complete_stats <- bind_cols(stats, status_counts)
  return(complete_stats)
}

# Function to prepare data and create time and memory comparison plots for two tools
plot_comparisons <- function(df, tool1, tool2) {
  fperf <- df %>%
    mutate(
      RepTime_1 = ifelse(get(paste("Status", tool1, sep = "_")) != "OK", 120000, get(paste("Time", tool1, sep = "_"))),
      RepTime_2 = ifelse(get(paste("Status", tool2, sep = "_")) != "OK", 120000, get(paste("Time", tool2, sep = "_"))),
      Mem_1     = ifelse(get(paste("Status", tool1, sep = "_")) != "OK", 16000000, get(paste("Mem", tool1, sep = "_"))),
      Mem_2     = ifelse(get(paste("Status", tool2, sep = "_")) != "OK", 16000000, get(paste("Mem", tool2, sep = "_"))),
      Verdict_Color = case_when(
        get(paste("Status", tool1, sep = "_")) == "OK" & get(paste("Status", tool2, sep = "_")) != "OK" ~ paste("Only", tool1, "solves"),
        get(paste("Status", tool2, sep = "_")) == "OK" & get(paste("Status", tool1, sep = "_")) != "OK" ~ paste("Only", tool2, "solves"),
        get(paste("Status", tool1, sep = "_")) == "OK" & get(paste("Status", tool2, sep = "_")) == "OK" ~ "Both tools solve",
        TRUE ~ "Both tools fail"
      )
    )
  
  # Compute caption: count the number of points for each Verdict_Color
  caption_text <- fperf %>%
    count(Verdict_Color) %>%
    mutate(text = paste(Verdict_Color, "(*", n, ")", sep = "")) %>%
    pull(text) %>%
    paste(collapse = "\n")
  
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
    guides(color = guide_legend(title = "Outcome")) +
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
    guides(color = guide_legend(title = "Outcome")) +
    xlab(paste("Memory for", tool1)) +
    ylab(paste("Memory for", tool2)) +
    ggtitle(paste("Memory usage comparison between", tool1, "and", tool2))
  
  return(list(Time_Comparison = time_plot, 
              Memory_Comparison = memory_plot, 
              Caption = caption_text))
}

# Process data split by Examination
examinations <- unique(data$Examination)

# Open PDF with landscape A4
pdf("Tool_Comparisons.pdf", paper = "a4r")
for (exam in examinations) {
  # Filter data for the current Examination
  exam_data <- data %>% filter(Examination == exam)
  
  # Pivot exam-specific data to wide format
  wide_data <- exam_data %>%
    pivot_wider(
      id_cols = "Model",
      names_from = Tool,
      values_from = c("Time", "Mem", "Status", "CardP", "CardT", "CardA", "NbPInv", "NbTInv", "Examination"),
      values_fn = list(
        Time = first, Mem = first, Status = first, 
        CardP = first, CardT = first, CardA = first, 
        NbPInv = first, NbTInv = first, Examination = first
      )
    ) %>%
    # Replace NA in Status columns with "UNK"
    mutate(across(contains("Status"), ~replace_na(., "UNK"))) %>%
    # Replace remaining NA in numeric columns with 0
    mutate(across(where(is.numeric), ~replace_na(., 0)))
  
  # Determine the tools for this Examination. If a filter was provided, intersect it.
  tools <- unique(exam_data$Tool)
  if (exists("tools_filter")) {
    tools <- intersect(tools, tools_filter)
  }
  
  # Skip if there are fewer than two tools to compare
  if (length(tools) < 2) {
    cat("Examination", exam, "has less than two tools. Skipping comparisons.\n")
    next
  }
  
  # Compute and print tool statistics for the current Examination
  tool_stats <- map_df(tools, ~get_tool_stats(.x, wide_data))
  tool_stats <- tool_stats %>% mutate(across(everything(), ~replace_na(., 0)))
  cat("Examination:", exam, "\n")
  print(tool_stats)
  
  # Create pairwise comparisons between tools
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
                     gp = gpar(fontsize = 14, fontface = "bold")),
      bottom = textGrob(plots$Caption, gp = gpar(fontsize = 10), 
                        x = 0.5, just = "center")
    )
  }
}
dev.off()
