# plots.R: Plotting functions

library(dplyr)
library(ggplot2)
library(gridExtra)
library(grid)

numeric_cols <- function(df) names(df)[sapply(df, is.numeric)]

plot_comparisons <- function(df, tool1, tool2, filter_name) {
  status_col1 <- paste("Status", tool1, sep = "_")
  status_col2 <- paste("Status", tool2, sep = "_")
  time_col1 <- paste("Time", tool1, sep = "_")
  time_col2 <- paste("Time", tool2, sep = "_")
  mem_col1 <- paste("Mem", tool1, sep = "_")
  mem_col2 <- paste("Mem", tool2, sep = "_")
  
  fperf <- df %>%
    filter(!is.na(.data[[time_col1]]) & !is.na(.data[[time_col2]]) &
           .data[[status_col1]] != "NA" & .data[[status_col2]] != "NA") %>%
    mutate(
      RepTime_1 = ifelse(.data[[status_col1]] != "OK", 120000, .data[[time_col1]]),
      RepTime_2 = ifelse(.data[[status_col2]] != "OK", 120000, .data[[time_col2]]),
      Mem_1 = ifelse(.data[[status_col1]] != "OK", 16000000, .data[[mem_col1]]),
      Mem_2 = ifelse(.data[[status_col2]] != "OK", 16000000, .data[[mem_col2]]),
      Verdict_Color = case_when(
        .data[[status_col1]] == "OK" & .data[[status_col2]] != "OK" ~ paste("Only", tool1, "solves"),
        .data[[status_col2]] == "OK" & .data[[status_col1]] != "OK" ~ paste("Only", tool2, "solves"),
        .data[[status_col1]] == "OK" & .data[[status_col2]] == "OK" ~ "Both tools solve",
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
    geom_point(size = 3) +
    scale_x_continuous(trans = 'log10', 
                       breaks = c(10, 100, 1000, 10000, 60000, 120000),
                       labels = c("0.01s", "0.1s", "1s", "10s", "1min", "2min")) +
    scale_y_continuous(trans = 'log10', 
                       breaks = c(10, 100, 1000, 10000, 60000, 120000),
                       labels = c("0.01s", "0.1s", "1s", "10s", "1min", "2min")) +
    geom_abline(intercept = 0, slope = 1) +
    scale_color_manual(values = c("orange", "blue", "green", "red")) +
    guides(color = guide_legend(title = legend_title)) +
    labs(x = paste("Time for", tool1), y = paste("Time for", tool2)) +
    theme_minimal() +
    theme(
      axis.title = element_text(size = 35, face = "bold"),
      axis.text = element_text(size = 35, face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1),
      panel.border = element_rect(colour = "black", fill = NA, size = 1)
    )
  
  memory_plot <- ggplot(fperf, aes(x = Mem_1, y = Mem_2, color = Verdict_Color)) +
    geom_point(size = 3) +
    scale_x_continuous(trans = 'log10', 
                       breaks = c(10000, 100000, 1000000, 3000000, 10000000, 16000000),
                       labels = c("10MB", "100MB", "1GB", "3GB", "10GB", "16GB")) +
    scale_y_continuous(trans = 'log10', 
                       breaks = c(10000, 100000, 1000000, 3000000, 10000000, 16000000),
                       labels = c("10MB", "100MB", "1GB", "3GB", "10GB", "16GB")) +
    geom_abline(intercept = 0, slope = 1) +
    scale_color_manual(values = c("orange", "blue", "green", "red")) +
    guides(color = guide_legend(title = legend_title)) +
    labs(x = paste("Memory for", tool1), y = paste("Memory for", tool2)) +
    theme_minimal() +
    theme(
      axis.title = element_text(size = 35, face = "bold"),
      axis.text = element_text(size = 35, face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1),
      panel.border = element_rect(colour = "black", fill = NA, size = 1)
    )
  
  pdf(paste0("pdf/scatter_", filter_name, "_", tool1, "_vs_", tool2, ".pdf"), width = 14, height = 20)
  grid.arrange(
    time_plot,
    memory_plot,
    ncol = 1,
    top = textGrob(paste("Examination:", filter_name, "- Comparison:", tool1, "vs", tool2), 
                   gp = gpar(fontsize = 14, fontface = "bold"))
  )
  dev.off()
}

plot_numerics <- function(df, filter_name) {
  pdf(paste0("pdf/Metrics_Plots_", filter_name, ".pdf"), width = 20, height = 14)
  exclude_cols <- c("CardP", "CardT", "CardA")  # Skip model description columns
  for (col in setdiff(numeric_cols(df), exclude_cols)) {
    if (all(is.na(df[[col]]))) next  # Skip if all NA due to filter
    non_na_counts <- df %>%
      group_by(Tool) %>%
      summarise(Count = sum(!is.na(.data[[col]])), .groups = "drop")
    df_plot <- df[!is.na(df[[col]]), ]
    df_plot$Tool <- paste(df_plot$Tool, " (", non_na_counts$Count[match(df_plot$Tool, non_na_counts$Tool)], ")", sep = "")
    p <- ggplot(df_plot, aes(x = Tool, y = .data[[col]])) +
      geom_boxplot() +
      scale_y_continuous(trans = "log10") +
      labs(
        x = "",
        y = col,
        title = paste("Distribution of", col, "-", filter_name)
      ) +
      theme_minimal() +
      theme(
        axis.title = element_text(size = 35, face = "bold"),
        axis.text = element_text(size = 35, face = "bold"),
        axis.text.x = element_text(angle = 45, hjust = 1),
        plot.caption = element_text(size = 20)
      )
    print(p)
  }
  dev.off()
}

plot_model_descriptions <- function(df) {
  pdf("pdf/Model_Descriptions.pdf", width = 20, height = 14)
  for (col in c("CardP", "CardT", "CardA")) {
    if (all(is.na(df[[col]]))) next
    p <- ggplot(df[!is.na(df[[col]]), ], aes(x = .data[[col]])) +
      geom_histogram(bins = 30) +
      scale_x_continuous(trans = "log10") +
      labs(
        x = col,
        y = "Count",
        title = paste("Distribution of", col, "Across All Models"),
        caption = paste("Non-NA points:", sum(!is.na(df[[col]])))
      ) +
      theme_minimal() +
      theme(
        axis.title = element_text(size = 35, face = "bold"),
        axis.text = element_text(size = 35, face = "bold"),
        plot.caption = element_text(size = 20)
      )
    print(p)
  }
  dev.off()
}