# utils.R: Utility functions

library(dplyr)

merge_tools <- function(df, tool1, tool2, metric) {
  df1 <- df[df$Tool == tool1, c("ID", metric)]
  df2 <- df[df$Tool == tool2, c("ID", metric)]
  names(df1)[2] <- paste0(metric, "_", tool1)
  names(df2)[2] <- paste0(metric, "_", tool2)
  merge(df1, df2, by = "ID")  # Inner join: only common points
}