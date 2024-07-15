import pandas as pd
import scipy.stats as stats
import seaborn as sns
import matplotlib.pyplot as plt
import sys

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
        ThermoData = ThermoData.drop(ThermoData.columns[[0, 1, 3, 4]], axis=1)
        ThermoData.set_index(ThermoData.columns[0], inplace=True)
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

    # Perform ANOVA
    anova_results = {}
    for condition in conditions:
        subset = filtered_meta_data[filtered_meta_data[column] == condition]
        data_columns = subset.columns[:-1]  # Exclude the last column which is the condition column
        anova_data = [subset[col] for col in data_columns]
        f_statistic, p_value = stats.f_oneway(*anova_data)
        anova_results[condition] = {'F-statistic': f_statistic, 'p-value': p_value}

    # Save ANOVA results to CSV
    anova_df = pd.DataFrame.from_dict(anova_results, orient='index')
    anova_df.index.name = hue_column  # Set index name to the dynamic hue column name
    anova_output_file = f"{output_path}/anova_results.csv"
    try:
        anova_df.to_csv(anova_output_file)
        print(f"ANOVA results saved to: {anova_output_file}")
    except PermissionError as e:
        print(f"Error: Permission denied to write to {anova_output_file}. Please check file permissions.")
        sys.exit(1)

    # Plot boxplot using seaborn
    plt.figure(figsize=(12, 8))
    try:
        # Prepare data for plotting
        plot_data = []
        for condition in conditions:
            subset = filtered_meta_data[filtered_meta_data[column] == condition].copy()
            subset[hue_column] = condition  # Add dynamic hue column based on config
            plot_data.append(subset)

        plot_data = pd.concat(plot_data, ignore_index=True)

        # Debugging prints
        print(plot_data.head())  # Check the structure of plot_data
        print(plot_data.columns)  # Check column names to ensure 'condition' is present

        # Melt the DataFrame to long format
        plot_data = pd.melt(plot_data, id_vars=[hue_column], var_name='Variable', value_name='Value')

        # Plot using seaborn boxplot with hue
        ax = sns.boxplot(x='Variable', y='Value', hue=hue_column, data=plot_data, palette='Set1')
        plt.title('ANOVA test')
        plt.xlabel('Variable')
        plt.ylabel('Value')
        plt.xticks(rotation=45)
        plt.tight_layout()

        # Save plot to file
        box_plot_file = f"{output_path}/box_plot.png"
        plt.savefig(box_plot_file)
        print(f"Box plot saved to: {box_plot_file}")
        plt.show()

    except PermissionError as e:
        print(f"Error: Permission denied to write to {box_plot_file}. Please check file permissions.")
        sys.exit(1)
    except KeyError as e:
        print(f"Error: Column '{hue_column}' not found in plot_data. Check data preparation steps.")
        sys.exit(1)
    except Exception as e:
        print(f"Error: An unexpected error occurred: {str(e)}")
        sys.exit(1)

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
