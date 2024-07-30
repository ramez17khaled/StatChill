import importlib.util
import subprocess
import sys
import os

# List of required libraries
required_libraries = ['pandas', 'scipy', 'seaborn', 'matplotlib', 'statsmodels']

# Check if each library is installed
for lib in required_libraries:
    spec = importlib.util.find_spec(lib)
    if spec is None:
        print(f"{lib} is not installed. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", lib])

# Now import the required libraries
import pandas as pd
import scipy.stats as stats
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages


def main(meta_file_path, file_path, sheet, output_path, column, conditions, hue_column):
    # Load the MetaData
    print("Loading metadata...")
    if meta_file_path.endswith(('.xlsx', '.xls')):
        meta_data = pd.read_excel(meta_file_path)
        meta_data.columns = [col.lower().replace(' ', '_') for col in meta_data.columns]
        meta_data.set_index('sample', inplace=True)
    elif meta_file_path.endswith('.csv'):
        meta_data = pd.read_csv(meta_file_path, sep=';')
        meta_data.columns = [col.lower().replace(' ', '_') for col in meta_data.columns]
        meta_data.set_index('sample', inplace=True)
    else:
        raise ValueError("Unsupported file format")
    print("MetaData loaded successfully:")
    print(meta_data.head())

    # Load the main data
    print("Loading main data...")
    if file_path.endswith(('.xlsx', '.xls')):
        ThermoData = pd.read_excel(file_path, sheet_name=sheet)
        ThermoData = ThermoData.drop(ThermoData.columns[[1, 2, 3, 4]], axis=1)
        ThermoData = ThermoData.groupby(ThermoData.columns[0]).mean()
        ThermoData = ThermoData.T
        ThermoData.index.name = 'sample'
    elif file_path.endswith('.csv'):
        ThermoData = pd.read_csv(file_path, sep=';')
        ThermoData = ThermoData.drop(ThermoData.columns[[0, 1, 3, 4]], axis=1)
        ThermoData.set_index(ThermoData.columns[0], inplace=True)
        ThermoData = ThermoData.T
        ThermoData.index.name = 'sample'
    else:
        raise ValueError("Unsupported file format")
    print("Main data loaded successfully:")
    print(ThermoData.head())

    # Ensure all data columns are numeric and handle non-numeric values
    ThermoData = ThermoData.apply(pd.to_numeric, errors='coerce')
    
    # Fill or drop NaN values
    ThermoData = ThermoData.fillna(0)  # Fill NaNs with 0, or use .dropna() to remove rows/columns with NaNs
    
    # Check if the column exists in the metadata
    if column not in meta_data.columns:
        print("Available columns in metadata:", meta_data.columns)
        raise KeyError(f"Column '{column}' not found in metadata")
    
    # Merging data-metadata
    print("Merging data...")
    selected_meta_data = meta_data[[column]]
    merged_data = pd.merge(ThermoData, selected_meta_data, on='sample', how='left')
    filtered_meta_data = merged_data[merged_data[column].isin(conditions)]
    print("Merged data:")
    print(merged_data.head())
    print("Filtered data:")
    print(filtered_meta_data.head())

    # Ensure the output directory exists
    if not os.path.exists(output_path):
        os.makedirs(output_path)

    # Save plots to a single PDF file
    pdf_path = os.path.join(output_path, 'family_plots.pdf')
    with PdfPages(pdf_path) as pdf:
        metabolites = ThermoData.columns
        for metabolite in metabolites:
            group1 = filtered_meta_data[filtered_meta_data[column] == conditions[0]][metabolite]
            group2 = filtered_meta_data[filtered_meta_data[column] == conditions[1]][metabolite]

            # Perform Shapiro-Wilk test for normality
            stat1, p1 = stats.shapiro(group1)
            stat2, p2 = stats.shapiro(group2)
            print(f'Shapiro-Wilk Test for {metabolite} - Condition 1: Statistic={stat1}, p-value={p1}')
            print(f'Shapiro-Wilk Test for {metabolite} - Condition 2: Statistic={stat2}, p-value={p2}')

            # Decide the test to use based on normality
            if p1 > 0.05 and p2 > 0.05:
                # Use t-test if both groups are normally distributed
                t_stat, t_p_value = stats.ttest_ind(group1, group2)
                p_value = t_p_value
                test_result = 't-test'
            else:
                # Use Mann-Whitney U test if either group is not normally distributed
                u_stat, u_p_value = stats.mannwhitneyu(group1, group2)
                p_value = u_p_value
                test_result = 'Mann-Whitney U test'

            print(f'{test_result}: p-value={p_value}')

            # Plotting
            plt.figure(figsize=(8, 6))
            sns.boxplot(x=column, y=metabolite, data=filtered_meta_data, hue=hue_column)
            plt.title(f'{metabolite} ({test_result})')
            plt.ylabel('Intensity')
            plt.xlabel('Condition')

            # Add significance annotation
            if p_value < 0.05:
                plt.annotate('*', xy=(0.5, 0.95), xycoords='axes fraction', ha='center', fontsize=20, color='red')

            # Save the plot to the PDF
            pdf.savefig()
            plt.close()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python ANOVA.py <config_file>")
        sys.exit(1)

    config_file = sys.argv[1]

    # Read config file to get inputs
    with open(config_file, 'r') as f:
        lines = f.readlines()
        config = {line.split('=')[0].strip(): line.split('=')[1].strip() for line in lines}

    # Extract variables from config
    meta_file_path = config.get('meta_file_path', '')
    file_path = config.get('file_path', '')
    sheet = config.get('sheet', '')
    output_path = config.get('output_path', '')
    column = config.get('column', '')
    conditions_str = config.get('conditions', '')
    conditions = conditions_str.split(',')
    hue_column = column  # Set the dynamic hue column from 'column' parameter

    # Call main function
    main(meta_file_path, file_path, sheet, output_path, column, conditions, hue_column)
