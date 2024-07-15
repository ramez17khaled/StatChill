import pandas as pd
import scipy.stats as stats
import seaborn as sns
import matplotlib.pyplot as plt
import sys
import numpy as np

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

        # Melt the DataFrame to long format
        plot_data = pd.melt(plot_data, id_vars=[hue_column], var_name='Variable', value_name='Value')

        # Plot using seaborn boxplot with hue
        ax = sns.boxplot(x='Variable', y='Value', hue=hue_column, data=plot_data, palette='Set1')
        
        # Add significance annotations
        add_stat_annotation(ax, data=plot_data, x='Variable', y='Value', hue=hue_column,
                            box_pairs=[(conditions[i], conditions[j]) for i in range(len(conditions)) for j in range(i+1, len(conditions))],
                            test='t-test_ind', text_format='star', loc='inside', verbose=2)
        
        plt.title('Box Plot by Condition')
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

def add_stat_annotation(ax, data=None, x=None, y=None, hue=None, box_pairs=None,
                        test='t-test', text_format='full', loc='inside', verbose=1):
    """
    Function to perform statistical test and add annotation on top of the boxplot.
    Parameters:
    - ax: matplotlib Axes object to draw on.
    - data: DataFrame containing data.
    - x: Name of the variable on x-axis.
    - y: Name of the variable on y-axis.
    - hue: Name of the variable that defines subsets in `data`.
    - box_pairs: List of tuples specifying pairs to compare (e.g., [('Group1', 'Group2'), ('Group3', 'Group4')]).
    - test: Statistical test to perform; 't-test' or 'Mann-Whitney'.
    - text_format: Format of the text annotation.
    - loc: Location of the annotation; 'inside' or 'outside'.
    - verbose: Level of verbosity; 0 (none) to 2 (highest).
    """
    def apply_stats_test(data, x, y, hue, box_pairs, test):
        """ Function to apply statistical test between groups. """
        results = {}
        for pair in box_pairs:
            group1 = data[data[hue] == pair[0]][y].dropna()
            group2 = data[data[hue] == pair[1]][y].dropna()

            if test == 't-test':
                stat, p = stats.ttest_ind(group1, group2)
            elif test == 'Mann-Whitney':
                stat, p = stats.mannwhitneyu(group1, group2)
            else:
                raise ValueError("Unsupported test type. Choose either 't-test' or 'Mann-Whitney'.")

            results[pair] = p

        return results

    def add_stat_annotation_text(ax, results, x, y, text_format, loc):
        """ Function to add text annotation based on statistical results. """
        for pair, pval in results.items():
            if text_format == 'full':
                text = f"{pair}: {pval:.2e}"
            elif text_format == 'star':
                text = get_pval_stars(pval)

            if loc == 'inside':
                height = max(data[y])
            elif loc == 'outside':
                height = max(data[y]) * 1.05

            x1, x2 = ax.get_xticks()[pair[0]], ax.get_xticks()[pair[1]]
            ax.plot([x1, x1, x2, x2], [height, height + height * 0.05, height + height * 0.05, height],
                    lw=1.5, c='black')
            ax.text((x1 + x2) * .5, height + height * 0.1, text, ha='center', va='bottom')

    def get_pval_stars(pval):
        """ Function to convert p-value to stars for significance levels. """
        if pval < 0.0001:
            return "****"
        elif (pval < 0.001):
            return "***"
        elif (pval < 0.01):
            return "**"
        elif (pval < 0.05):
            return "*"
        else:
            return "ns"

    if verbose >= 1:
        print(f"Adding statistical annotation based on {test} test")

    # Apply statistical test
    results = apply_stats_test(data, x, y, hue, box_pairs, test)

    # Add annotation to the plot
    add_stat_annotation_text(ax, results, x, y, text_format, loc)


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
