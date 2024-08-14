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
required_packages <- c("readxl", "ggplot2","dplyr","tidyverse", "ggforce", "scales", "cowplot", "reshape2")

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
library(reshape2)

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
    row.names(data) <- data$sample_id  # Assuming 'sample_id' is the row identifier
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

#data preparation
main_data <- main_data[, -c(2)]

souFamille_main_data <- main_data[, -1]
souFamille_main_data <- souFamille_main_data %>%
  column_to_rownames(var = colnames(souFamille_main_data)[1])

T_souFamille_main_data <- t(souFamille_main_data)

filtered_meta <- meta_data[meta_data[[column]] %in% conditions, , drop = FALSE]
filtered_souFamilleData <- T_souFamille_main_data[row.names(T_souFamille_main_data) %in% row.names(filtered_meta), ]

# Ensure all columns in filtered_data are numeric
filtered_souFamilleData <- apply(filtered_souFamilleData, 2, as.numeric)
filtered_souFamilleData_df <- as.data.frame(filtered_souFamilleData)

filtered_souFamilleData_df[[column]] <- filtered_meta[[column]]
filtered_souFamilleData_df[[column]] <- as.factor(filtered_souFamilleData_df[[column]])

metabolite_famille_mapping <- main_data %>%
  select(1, 2) %>%
  distinct()

metabolite_famille_mapping <- unique(metabolite_famille_mapping)
metabolite_famille_mapping <- metabolite_famille_mapping %>%
  rename(Metabolite = `Metaolite name`)

long_souFamilleData <- filtered_souFamilleData_df %>%
  pivot_longer(cols = -all_of(column), names_to = "Metabolite", values_to = "Value")
long_souFamilleData_with_famille <- long_souFamilleData %>%
  left_join(metabolite_famille_mapping, by = "Metabolite")
names(long_souFamilleData_with_famille)[4] <- "group"

empty_bar <- 3
to_add <- data.frame( matrix(NA, empty_bar*nlevels(factor(long_souFamilleData_with_famille$group)), ncol(long_souFamilleData_with_famille)) )
colnames(to_add) <- colnames(long_souFamilleData_with_famille)
to_add$group <- rep(levels(factor(long_souFamilleData_with_famille$group)), each=empty_bar)
long_souFamilleData_with_famille <- rbind(long_souFamilleData_with_famille, to_add)
long_souFamilleData_with_famille <- long_souFamilleData_with_famille %>% arrange(group)
long_souFamilleData_with_famille$id <- seq(1, nrow(long_souFamilleData_with_famille))

label_data <- long_souFamilleData_with_famille
number_of_bar <- nrow(label_data)
angle <- 90 - 360 * (label_data$id-0.5) / number_of_bar    
label_data$hjust <- ifelse(angle < -90, 1, 0)
label_data$angle <- ifelse(angle < -90, angle+180, angle)

base_data <- long_souFamilleData_with_famille %>%
  # ABBREVIATE GROUP NAME
  mutate(group = paste0(sapply(strsplit(group, " "), `[`, 1), "...")) %>%
  group_by(group) %>% 
  summarize(start=min(id), end=max(id) - empty_bar) %>%
  rowwise() %>% 
  mutate(title=mean(c(start, end)))

base_data <- base_data %>%
  # ADD ANGLE AND HJUST COLUMNS
  transform(angle = 90 - 360 * (seq(1, nrow(base_data))-0.5) / nrow(base_data)) %>%
  mutate(angle = ifelse(angle < -90, angle+180, angle),
         hjust = ifelse(angle < -90, 1, 0))

grid_data <- base_data
grid_data$end <- grid_data$end[ c( nrow(grid_data), 1:nrow(grid_data)-1)] + 1
grid_data$start <- grid_data$start - 1

grid_lines <- rep(seq(90, 0, length.out = nrow(grid_data)), each = 2)

souFamille_plot <- ggplot(long_souFamilleData_with_famille, aes(x = as.factor(id), y = Value, fill = group)) +       
  geom_bar(stat = "identity", alpha = 0.5) +
  
  # Add grid lines
  geom_segment(data = grid_data, aes(x = end, y = grid_lines[seq(1, length(grid_lines), by = 2)], 
                                     xend = start, yend = grid_lines[seq(2, length(grid_lines), by = 2)]), 
               colour = "grey", alpha = 1, size = 0.3, inherit.aes = FALSE) +
  
  # Add annotation for y-axis labels
  annotate("text", x = rep(max(long_souFamilleData_with_famille$id), 4), y = c(20, 40, 60, 80),
           label = c("20", "40", "60", "80"), color = "grey", size = 3, 
           angle = 0, fontface = "bold", hjust = 1) +
  
  ylim(-100, 120) +
  theme_minimal() +
  theme(
    legend.position = "none",
    axis.text = element_blank(),
    axis.title = element_blank(),
    panel.grid = element_blank(),
    plot.margin = unit(rep(-1, 4), "cm") 
  ) +
  coord_polar() +
  
  # Add text labels for bars
  geom_text(data = label_data, 
            aes(x = id, y = Value + 10, label = Metabolite, hjust = hjust), 
            color = "black", fontface = "bold", alpha = 0.6, size = 2.5,
            angle = label_data$angle, inherit.aes = FALSE) +
  
  # Add segments and labels for base data
  geom_segment(data = base_data, 
               aes(x = start, y = -5, xend = end, yend = -5), 
               colour = "black", alpha = 0.8, linewidth = 0.6, inherit.aes = FALSE) +
  
  geom_text(data = base_data, 
            aes(x = title, y = -18, label = group),
            hjust = base_data$hjust, colour = "black", alpha = 0.8, size = 4,
            angle = base_data$angle, fontface = "bold", inherit.aes = FALSE)

output_file <- file.path(output_path, paste0("myGroupCircularBarChart.png"))
ggsave(output_file, plot = souFamille_plot, width = 6, height = 6, dpi = 300)


#########################################################
plot_circular_bars <- function(data, family_name) {
  # Arrange data and compute angles and horizontal adjustments
  data <- data %>%
    arrange(id) %>%
    mutate(
      angle = 90 - 360 * (id - 0.5) / nrow(data),
      angle = ifelse(angle < -90, angle + 180, angle),
      hjust = ifelse(angle < -90, 1, 0)
    )
  
  # Compute grid_data with correct values
  grid_data <- data %>%
    group_by(group) %>%
    summarize(start = min(id), end = max(id)) %>%
    ungroup() %>%
    mutate(start = start - 1, end = end + 1)
  
  # Create a vector for grid_lines
  grid_lines <- seq(0, 100, length.out = nrow(grid_data) * 2)
  
  ggplot(data, aes(x = as.factor(id), y = Value, fill = group)) +       
    geom_bar(stat = "identity", alpha = 0.5) +
    
    # Add grid lines
    geom_segment(data = grid_data,
                 aes(x = end, y = grid_lines[seq(1, length(grid_lines), by = 2)], 
                     xend = start, yend = grid_lines[seq(2, length(grid_lines), by = 2)]), 
                 colour = "grey", alpha = 1, linewidth = 0.3, inherit.aes = FALSE) +
    
    # Add annotation for y-axis labels
    annotate("text", x = rep(max(data$id), 4), y = c(20, 40, 60, 80),
             label = c("20", "40", "60", "80"), color = "grey", size = 3, 
             angle = 0, fontface = "bold", hjust = 1) +
    
    ylim(-100, 120) +
    theme_minimal() +
    theme(
      legend.position = "none",
      axis.text = element_blank(),
      axis.title = element_blank(),
      panel.grid = element_blank(),
      plot.margin = unit(rep(-1, 4), "cm") 
    ) +
    coord_polar() +
    
    # Add text labels for bars
    geom_text(data = data, 
              aes(x = id, y = Value + 10, label = Metabolite, hjust = hjust, angle = angle), 
              color = "black", fontface = "bold", alpha = 0.6, size = 2.5,
              inherit.aes = FALSE) +
    
    # Add segments and labels for base data
    geom_segment(data = grid_data,
                 aes(x = start, y = -5, xend = end, yend = -5), 
                 colour = "black", alpha = 0.8, linewidth = 0.6, inherit.aes = FALSE) +
    
    geom_text(data = grid_data %>%
                mutate(title = mean(c(start, end))),
              aes(x = title, y = -18, label = group),
              hjust = 0.5, colour = "black", alpha = 0.8, size = 4,
              angle = 0, fontface = "bold", inherit.aes = FALSE) +
    
    ggtitle(family_name)  # Add a title with the family name
}

# loop
unique_groups <- unique(long_souFamilleData_with_famille$group)

for (famille in unique_groups) {
  # Filter data for the current family and remove NA values
  family_data <- long_souFamilleData_with_famille %>%
    filter(group == famille) %>%
    filter(!is.na(condition) & !is.na(Metabolite) & !is.na(Value)) # Remove rows with NA values
  
  # Prepare the data for the heatmap by aggregating duplicate entries
  heatmap_data <- family_data %>%
    group_by(condition, Metabolite) %>%
    summarise(Value = mean(Value, na.rm = TRUE), .groups = 'drop') %>%
    pivot_wider(names_from = Metabolite, values_from = Value, values_fill = list(Value = 0)) %>%
    # Remove any rows or columns where all values are NA
    filter(rowSums(!is.na(across(-condition))) > 0) %>%
    select(where(~ !all(is.na(.)))) 
  
  # Convert to matrix for heatmap
  heatmap_matrix <- as.matrix(heatmap_data[,-1]) # Remove condition column
  rownames(heatmap_matrix) <- heatmap_data$condition
  
  # Prepare data for ggplot
  melted_heatmap <- melt(heatmap_matrix)
  colnames(melted_heatmap) <- c("Condition", "Metabolite", "Value")
  
  # Remove rows with NA values in the melted data
  melted_heatmap <- melted_heatmap %>% filter(!is.na(Condition) & !is.na(Metabolite) & !is.na(Value))
  
  # Create a heatmap
  p_heatmap <- ggplot(melted_heatmap, aes(x = Metabolite, y = Condition, fill = Value)) +
    geom_tile() +
    scale_fill_gradient(low = "darkgray", high = "brown3") +
    labs(x = "Metabolite Subclasses", y = "Condition", fill = "Value", title = paste("Heatmap for", famille)) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  # Save each heatmap to a file
  output_file <- file.path(output_path, paste0("heatmap_", gsub(" ", "_", famille), ".png"))
  ggsave(output_file, plot = p_heatmap, width = 10, height = 8, dpi = 300)
}


##########################################################

p1 <- ggplot(data, aes(x = as.factor(id), y = Value, fill = "TG")) +       
  geom_bar(stat = "identity", width = 0.8, alpha = 0.7) +
  geom_segment(data = grid_data,
               aes(x = end, y = 100, xend = start, yend = 100), 
               colour = "grey", alpha = 1, linewidth = 0.3, inherit.aes = FALSE) +
  annotate("text", x = rep(max(data$id), 4), y = c(20, 40, 60, 80),
           label = c("20", "40", "60", "80"), color = "grey", size = 3, 
           angle = 0, fontface = "bold", hjust = 1) +
  
  ylim(-100, 120) +
  theme_minimal() +
  theme(
    legend.position = "none",
    axis.text = element_blank(),
    axis.title = element_blank(),
    panel.grid = element_blank(),
    plot.margin = unit(rep(-1, 4), "cm") 
  ) +
  coord_polar() +
  geom_text(data = data, 
            aes(x = id, y = Value + 10, label = Metabolite, hjust = hjust, angle = angle), 
            color = "black", fontface = "bold", alpha = 0.6, size = 2.5,
            inherit.aes = FALSE) +
  geom_segment(data = grid_data,
               aes(x = start, y = -5, xend = end, yend = -5), 
               colour = "black", alpha = 0.8, linewidth = 0.6, inherit.aes = FALSE) +
  geom_text(data = grid_data %>%
              mutate(title = mean(c(start, end))),
            aes(x = title, y = -18, label = group),
            hjust = 0.5, colour = "black", alpha = 0.8, size = 4,
            angle = 0, fontface = "bold", inherit.aes = FALSE) +
  
  ggtitle("TG")  # Add a title with the family name
p1


