library(dplyr)
library(tidyr)
library(purrr)
library(ggplot2)
library(grid)
library(gridExtra)


# Load data
data <- read.csv("invar.csv", dec = ".", sep = ",", header = TRUE, stringsAsFactors = FALSE)

# Filter out all models containing "COL"
data <- data %>% 
  filter(!grepl("COL", Model))

# Pivot data to wide format
wide_data <- data %>%
  pivot_wider(
    names_from = Tool,
    values_from = c("Time", "Mem", "Status", "PTime", "TTime", "TotalTime", "CardP", "CardT", "CardA", "ConstP", "NBP", "NBT"),
    values_fn = list(Time = first, Mem = first, Status = first, PTime = first, TTime = first, TotalTime = first, CardP = first, CardT = first, CardA = first, ConstP = first, NBP = first, NBT = first),
    id_cols = "Model"
  ) %>%
  # Replace NA in Status columns with "UNK"
  mutate(across(contains("Status"), ~replace_na(., "UNK"))) %>%
  # Replace NA in numerical columns with 0
  mutate(across(where(is.numeric), ~replace_na(., 0)))


# Extract columns for each tool
tools <- unique(data$Tool)


# Define function to get tool statistics including tool name, status breakdown, and counts of NBP and NBT >= 0
get_tool_stats <- function(tool, df) {
  # Prepare the column names
  mean_time_col <- paste("Time", tool, sep = "_")
  mean_mem_col <- paste("Mem", tool, sep = "_")
  status_col <- paste("Status", tool, sep = "_")
  nbp_col <- paste("NBP", tool, sep = "_")
  nbt_col <- paste("NBT", tool, sep = "_")
  
  # Aggregate statistics for the tool
  stats <- df %>%
    summarise(
      Tool = first(tool),  # Include tool name
      Mean_Time = mean(get(mean_time_col), na.rm = TRUE),
      Mean_Mem = mean(get(mean_mem_col), na.rm = TRUE),
      INVP_OK = sum(get(nbp_col) >= 0, na.rm = TRUE),  # Count of NBP >= 0
      INVT_OK = sum(get(nbt_col) >= 0, na.rm = TRUE),  # Count of NBT >= 0
      .groups = 'drop'  # Dropping groups to prevent regrouping messages
    )
  
  # Get counts of each status
  status_counts <- df %>%
    group_by(!!rlang::sym(status_col)) %>%
    summarise(n = n(), .groups = 'drop') %>%
    pivot_wider(names_from = !!rlang::sym(status_col), values_from = n, values_fill = list(n = 0)) %>%
    rename_with(~ paste("Status", ., sep = "_"), everything()) # Prefixing status columns for clarity
  
  # Combine the general stats with the status counts
  complete_stats <- bind_cols(stats, status_counts)
  
  return(complete_stats)
}

# Use this function with map_df to gather stats for all tools
tool_stats <- map_df(tools, ~get_tool_stats(.x, wide_data))

# Replace any remaining NA values with 0
tool_stats <- tool_stats %>%
  mutate(across(everything(), ~replace_na(., 0)))

# Print the result
options(dplyr.width = Inf)
tool_stats


# Assuming wide_data is already loaded and prepared
tools <- unique(data$Tool)


# Function to prepare data and plot both time and memory comparisons
plot_comparisons <- function(df, tool1, tool2) {
  # Prepare data
  fperf <- df %>%
    mutate(
      RepTime_1 = ifelse(get(paste("Status", tool1, sep = "_")) != "OK", 120000, get(paste("PTime", tool1, sep = "_")) + get(paste("TTime", tool1, sep = "_"))),
      RepTime_2 = ifelse(get(paste("Status", tool2, sep = "_")) != "OK", 120000, get(paste("PTime", tool2, sep = "_")) + get(paste("TTime", tool2, sep = "_"))),
      Mem_1 = ifelse(get(paste("Status", tool1, sep = "_")) != "OK", 16000000, get(paste("Mem", tool1, sep = "_"))),
      Mem_2 = ifelse(get(paste("Status", tool2, sep = "_")) != "OK", 16000000, get(paste("Mem", tool2, sep = "_"))),
      Verdict_Color = case_when(
        get(paste("Status", tool1, sep = "_")) == "OK" & get(paste("Status", tool2, sep = "_")) != "OK" ~ paste("Only", tool1, "solves"),
        get(paste("Status", tool2, sep = "_")) == "OK" & get(paste("Status", tool1, sep = "_")) != "OK" ~ paste("Only", tool2, "solves"),
        get(paste("Status", tool1, sep = "_")) == "OK" & get(paste("Status", tool2, sep = "_")) == "OK" ~ "Both tools solve",
        TRUE ~ "Both tools fail"
      )
    )
  
  # Plot time comparison
  time_plot <- ggplot(fperf, aes(x = RepTime_1, y = RepTime_2, color = Verdict_Color)) +
    geom_point() +
    scale_x_continuous(trans = 'log10', breaks = c(10, 100, 1000, 10000, 60000, 120000), labels = c("0.01s", "0.1s", "1s", "10s", "1min", "2min")) +
    scale_y_continuous(trans = 'log10', breaks = c(10, 100, 1000, 10000, 60000, 120000), labels = c("0.01s", "0.1s", "1s", "10s", "1min", "2min")) +
    geom_abline(intercept = 0, slope = 1) +
    scale_color_manual(values = c("orange", "blue", "green", "red")) +
    guides(color = guide_legend(title = "Outcome")) +
    xlab(paste("Time for", tool1)) +
    ylab(paste("Time for", tool2)) +
    ggtitle(paste("Run time comparison between", tool1, "and", tool2))
  
  # Plot memory comparison
  memory_plot <- ggplot(fperf, aes(x = Mem_1, y = Mem_2, color = Verdict_Color)) +
    geom_point() +
    scale_x_continuous(trans = 'log10', breaks = c(10000, 100000, 1000000, 3000000, 10000000, 16000000), labels = c("10MB", "100MB", "1GB", "3GB", "10GB", "16GB")) +
    scale_y_continuous(trans = 'log10', breaks = c(10000, 100000, 1000000, 3000000, 10000000, 16000000), labels = c("10MB", "100MB", "1GB", "3GB", "10GB", "16GB")) +
    geom_abline(intercept = 0, slope = 1) +
    scale_color_manual(values = c("orange", "blue", "green", "red")) +
    guides(color = guide_legend(title = "Outcome")) +
    xlab(paste("Memory for", tool1)) +
    ylab(paste("Memory for", tool2)) +
    ggtitle(paste("Memory usage comparison between", tool1, "and", tool2))
  
  # Return both plots
  list(Time_Comparison = time_plot, Memory_Comparison = memory_plot)
}


tools <- unique(data$Tool)
combinations <- combn(tools, 2, simplify = FALSE)


# Create the PDF with landscape orientation
pdf("Tool_Comparisons.pdf")

# Generate and plot comparisons
for(combo in combinations) {
  tool1 <- combo[1]
  tool2 <- combo[2]
  plots <- plot_comparisons(wide_data, tool1, tool2)
  grid.arrange(plots$Time_Comparison, plots$Memory_Comparison, ncol = 1)
}

dev.off()