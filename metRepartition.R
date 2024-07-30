# Function to install and load required packages
install_and_load <- function(packages) {
  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE)) {
      install.packages(pkg, dependencies = TRUE)
      library(pkg, character.only = TRUE)
    }
  }
}

# List of required packages
required_packages <- c("readxl", "ggplot2","dplyr","tidyverse", "ggforce", "scales", "cowplot")

# Install and load required packages
install_and_load(required_packages)

# Load required libraries
library(readxl)
library(ggplot2)
library(dplyr)
library(tidyverse)
library(ggforce)
library(scales)
library(cowplot)

# Function to read file based on type
read_file <- function(file_path, sheet_name = NULL) {
  # Check if file exists
  if (!file.exists(file_path)) {
    stop("File not found.")
  }
  
  # Extract file extension
  file_ext <- tools::file_ext(file_path)
  
  # Read file based on extension
  if (file_ext == "csv") {
    # Read CSV file
    data <- read.csv(file_path, stringsAsFactors = FALSE, sep = ';')
    colnames(data) <- tolower(gsub(" ", "_", colnames(data)))
    row.names(data) <- data$sample  # Assuming 'sample' is the row identifier
  } else if (file_ext %in% c("xlsx", "xls")) {
    # Read XLSX or XLS file
    if (is.null(sheet_name)) {
      stop("Sheet name must be specified for Excel files.")
    }
    data <- readxl::read_excel(file_path, sheet = sheet_name)

  } else {
    stop("Unsupported file format. Only CSV and XLSX/XLS files are supported.")
  }
  
  return(data)
}

# Read input file paths and conditions from config.txt
config_file <- "config.txt"
config <- read.table(config_file, sep = "=", stringsAsFactors = FALSE, strip.white = TRUE)

# Assign variables from config file
meta_file_path <- trimws(config[grepl("^meta_file_path", config$V1), "V2"])
file_path <- trimws(config[grepl("^file_path", config$V1), "V2"])
sheet <- trimws(config[grepl("^sheet", config$V1), "V2"])
output_path <- trimws(config[grepl("^output_path", config$V1), "V2"])
column <- trimws(config[grepl("^column", config$V1), "V2"])
conditions <- trimws(config[grepl("^conditions", config$V1), "V2"])
label_column <- trimws(config[grepl("^label_column", config$V1), "V2"])

# Parse conditions
conditions <- strsplit(conditions, ",")[[1]]

# Load metadata
meta_data <- read_file(meta_file_path)

# Load main data with specific sheet
main_data <- read_file(file_path, sheet)

#data preprocessing
main_data <- main_data[, -c(2, 4, 5)]  # Drop specific columns

Famille_main_data_base <- main_data[, -2]
Famille_main_data <- Famille_main_data_base %>%
  group_by(Famille) %>%
  summarize(across(where(is.numeric), mean, na.rm = TRUE), .groups = 'drop')
Famille_main_data <- Famille_main_data %>%
  column_to_rownames(var = colnames(Famille_main_data)[1])

souFamille_main_data <- main_data[, -1]
souFamille_main_data <- souFamille_main_data %>%
  column_to_rownames(var = colnames(souFamille_main_data)[1])

T_Famille_main_data <- t(Famille_main_data) 

# Check if the column exists in the metadata
if (!(column %in% colnames(meta_data))) {
  stop(sprintf("Column '%s' not found in metadata.", column))
}

filtered_meta <- meta_data[meta_data[[column]] %in% conditions, , drop = FALSE]
filtered_data <- T_Famille_main_data[row.names(T_Famille_main_data) %in% row.names(filtered_meta), ]

# Ensure all columns in filtered_data are numeric
filtered_data <- apply(filtered_data, 2, as.numeric)
filtered_data_df <- as.data.frame(filtered_data)

filtered_data_df[[column]] <- filtered_meta[[column]]
filtered_data_df[[column]] <- as.factor(filtered_data_df[[column]])
long_data <- filtered_data_df %>%
  pivot_longer(cols = -all_of(column), names_to = "Metabolite", values_to = "Value")

#bar plot
famille_plot <- ggplot(long_data, aes(x = !!sym(column), y = Value, fill = Metabolite)) +
  geom_bar(stat = "identity") +
  labs(title = "Distribution of Metabolites Across Conditions", x = column, y = "Intensity") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
output_file <- file.path(output_path, "famille_plot.png")
ggsave(output_file, plot = famille_plot, width = 10, height = 6, dpi = 300)

cat("Plot saved as:", output_file, "\n")

#circular plot

# Calculate percentages
total_values <- long_data %>%
  group_by(!!sym(column)) %>%
  summarize(Total = sum(Value, na.rm = TRUE), .groups = 'drop')

Percentage_long_data <- long_data %>%
  left_join(total_values, by = column) %>%
  mutate(Percentage = (Value / Total) * 100)

# Assuming Percentage_long_data is your original data
aggregated_data <- Percentage_long_data %>%
  group_by(!!sym(column), Metabolite) %>%
  summarize(Value = sum(Value), Total = unique(Total), .groups = 'drop') %>%
  mutate(Percentage = (Value / Total) * 100)

# Ensure the column used for conditions is a character
aggregated_data[[column]] <- as.character(aggregated_data[[column]])

# Check unique conditions
conditions <- unique(aggregated_data[[column]])
print("Unique conditions:")
print(conditions)

# Assuming Percentage_long_data is your original data
aggregated_data <- Percentage_long_data %>%
  group_by(!!sym(column), Metabolite) %>%
  summarize(Value = sum(Value), Total = unique(Total), .groups = 'drop') %>%
  mutate(Percentage = (Value / Total) * 100)

# Ensure the column used for conditions is a character
aggregated_data[[column]] <- as.character(aggregated_data[[column]])

# Check unique conditions
conditions <- unique(aggregated_data[[column]])
print("Unique conditions:")
print(conditions)

# Define the function to create and save circular plots with percentage labels
conditions <- unique(aggregated_data[[column]])
print(conditions) 
for (cond in conditions) {
  cond <- as.character(cond)
  condition_data <- aggregated_data %>%
    filter(!!sym(column) == cond) %>%
    arrange(desc(Percentage))
  p <- ggplot(condition_data, aes(x = "", y = Percentage, fill = Metabolite)) +
    geom_bar(stat = "identity", width = 1) +
    coord_polar(theta = "y") +
    labs(title = paste("Metabolite Distribution for", cond)) +
    theme_void() +
    theme(legend.title = element_blank())
  output_file <- file.path(output_path, paste0("metabolite_distribution_", cond, ".png"))
  ggsave(output_file, plot = p, width = 6, height = 6, dpi = 300)
  cat("Plot saved for condition:", cond, "at", output_file, "\n")
}


########## Function to create and save faceted bar plots
create_faceted_plot <- function(data, output_dir) {
  p <- ggplot(data, aes(x = reorder(Metabolite, -Percentage), y = Percentage, fill = Metabolite)) +
    geom_bar(stat = "identity") +
    facet_wrap(~ condition, scales = "free_y") +
    labs(title = "Metabolite Distribution Across Conditions", x = "Metabolite", y = "Percentage") +
    theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
    theme(legend.position = "none")
  
  output_file <- file.path(output_dir, "metabolite_distribution_faceted.png")
  ggsave(output_file, plot = p, width = 12, height = 8)
}

# Generate and save faceted plot
create_faceted_plot(aggregated_data, output_path)
################################################################


