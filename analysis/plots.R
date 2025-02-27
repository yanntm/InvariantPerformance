# plots.R: Plotting functions

library(dplyr)
library(ggplot2)
library(gridExtra)

numeric_cols <- function(df) names(df)[sapply(df, is.numeric)]

plot_comparisons <- function(df, tool1, tool2, metric, filter_name) {
  merged <- merge_tools(df, tool1, tool2, metric)  # From utils.R
  fperf <- merged %>%
    mutate(
      Verdict_Color = case_when(
        !is.na(get(paste0(metric, "_", tool1))) & is.na(get(paste0(metric, "_", tool2))) ~ paste("Only", tool1, "solves"),
        !is.na(get(paste0(metric, "_", tool2))) & is.na(get(paste0(metric, "_", tool1))) ~ paste("Only", tool2, "solves"),
        !is.na(get(paste0(metric, "_", tool1))) & !is.na(get(paste0(metric, "_", tool2))) ~ "Both tools solve",
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
  
  p <- ggplot(fperf, aes_string(x = paste0(metric, "_", tool1), y = paste0(metric, "_", tool2), color = "Verdict_Color")) +
    geom_point() +
    scale_x_continuous(trans = "log10") +
    scale_y_continuous(trans = "log10") +
    geom_abline(intercept = 0, slope = 1) +
    labs(
      x = paste(metric, "for", tool1),
      y = paste(metric, "for", tool2),
      title = paste(metric, "Comparison -", filter_name),
      color = legend_title
    ) +
    theme_minimal() +
    theme(
      axis.title = element_text(size = 35, face = "bold"),
      axis.text = element_text(size = 35, face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1)
    )
  
  pdf(paste0("scatter_", metric, "_", filter_name, "_", tool1, "_vs_", tool2, ".pdf"), width = 20, height = 14)
  print(p)
  dev.off()
}

plot_numerics <- function(df, filter_name) {
  pdf(paste0("Metrics_Plots_", filter_name, ".pdf"), width = 20, height = 14)
  for (col in numeric_cols(df)) {
    p <- ggplot(df, aes_string(x = "Tool", y = col)) +
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
        axis.text.x = element_text(angle = 45, hjust = 1)
      )
    print(p)
  }
  dev.off()
}