# data_prep.R: Data loading, cleaning, and filtering

library(dplyr)

load_and_clean_data <- function(file) {
  data <- read.csv(file, dec = ".", sep = ",", header = TRUE, stringsAsFactors = FALSE)
  data[data == -1] <- NA  # Replace -1 with NA
  data <- data[!grepl("COL", data$Model), ]  # Exclude COL models
  data$ID <- paste(data$Model, data$Examination, sep = "_")  # Add ID column
  return(data)
}

filter_data <- function(data, condition) {
  if (isTRUE(condition)) return(data)
  subset(data, eval(condition))
}