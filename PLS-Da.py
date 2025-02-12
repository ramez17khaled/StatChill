import importlib.util
import subprocess
import sys
import os

# List of required libraries
required_libraries = ['tkinter', 'pandas', 'numpy', 'scikit-learn', 'matplotlib', 'openpyxl']

# Check if each library is installed
for lib in required_libraries:
    spec = importlib.util.find_spec(lib)
    if spec is None:
        print(f"{lib} is not installed. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", lib])

# Now import the required libraries
import tkinter as tk
import openpyxl
from tkinter import filedialog, messagebox
import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.cross_decomposition import PLSRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, confusion_matrix, roc_curve, roc_auc_score
import matplotlib.pyplot as plt

def main(meta_file_path, file_path, sheet, output_path, column, conditions):
    # Load the MetaData
    print("Loading metadata...")
    if meta_file_path.endswith(('.xlsx', '.xls')):
        meta_data = pd.read_excel(meta_file_path)
        meta_data.columns = [col.lower().replace(' ', '_') for col in meta_data.columns]
        meta_data.set_index('sample_id', inplace=True)
    elif meta_file_path.endswith('.csv'):
        meta_data = pd.read_csv(meta_file_path, sep=';')
        meta_data.columns = [col.lower().replace(' ', '_') for col in meta_data.columns]
        meta_data.set_index('sample_id', inplace=True)
    else:
        raise ValueError("Unsupported file format")
    print("MetaData loaded successfully:")
    print(meta_data.head())

    # Load the main data
    print("Loading main data...")
    if file_path.endswith(('.xlsx', '.xls')):
        ThermoData = pd.read_excel(file_path, sheet_name=sheet)
        ThermoData = ThermoData.drop(ThermoData.columns[[0, 2, 3]], axis=1)
        ThermoData.columns = [col.replace(' ', '_') for col in ThermoData.columns]
        ThermoData.set_index(ThermoData.columns[0], inplace=True)
        ThermoData = ThermoData.T
        ThermoData.index.name = 'sample_id'
    elif file_path.endswith('.csv'):
        ThermoData = pd.read_csv(file_path, sep=';')
        ThermoData = ThermoData.drop(ThermoData.columns[[0, 2, 3]], axis=1)
        ThermoData.columns = [col.replace(' ', '_') for col in ThermoData.columns]
        ThermoData.set_index(ThermoData.columns[0], inplace=True)
        ThermoData = ThermoData.T
        ThermoData.index.name = 'sample_id'
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
    merged_data = pd.merge(ThermoData, selected_meta_data, on='sample_id', how='left')
    filtered_meta_data = merged_data[merged_data[column].isin(conditions)]
    print("Merged data:")
    print(merged_data.head())
    print("Filtered data:")
    print(filtered_meta_data.head())

    # Separate features (metabolites) and target (condition)
    X = filtered_meta_data.drop(column, axis=1)  # Features (metabolites)
    y = filtered_meta_data[column]  # Target (conditions)
    
    # Check if the filtered data is empty
    if X.empty:
        print("Filtered data is empty. No samples match the given conditions.")
        sys.exit(1)
    
    print("Features (X):")
    print(X.head())
    print("Target (y):")
    print(y.head())

    # Encode the target labels
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)
    print("Encoded target (y):")
    print(y_encoded)

    # Standardize the features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    print("Scaled features (X_scaled):")
    print(X_scaled[:5])

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y_encoded, test_size=0.2, random_state=42)
    print("Training set size:", X_train.shape)
    print("Test set size:", X_test.shape)

    # Initialize PLS-DA model with 2 components
    pls_da = PLSRegression(n_components=2)

    # Fit the model
    pls_da.fit(X_train, y_train)

    # Transform data to the PLS-DA space
    X_train_pls = pls_da.transform(X_train)
    X_test_pls = pls_da.transform(X_test)

    # Predict on the test set
    y_pred = pls_da.predict(X_test)
    y_pred_class = (y_pred > 0.5).astype(int).flatten()
    print("Predicted classes (y_pred_class):")
    print(y_pred_class)

    # Evaluate model performance
    accuracy = accuracy_score(y_test, y_pred_class)
    conf_matrix = confusion_matrix(y_test, y_pred_class)
    print(f"Accuracy: {accuracy}")
    print(f"Confusion Matrix:\n{conf_matrix}")

    # PLS-DA plot
    plt.figure(figsize=(10, 7))
    plt.scatter(X_train_pls[:, 0], X_train_pls[:, 1], c=y_train, cmap='viridis', label='Train')
    plt.scatter(X_test_pls[:, 0], X_test_pls[:, 1], c=y_test, cmap='coolwarm', marker='x', label='Test')
    plt.xlabel('PLS Component 1')
    plt.ylabel('PLS Component 2')
    plt.title('PLS-DA Plot')
    plt.legend()
    pls_da_plot_path = os.path.join(output_path, 'PLS_DA_plot.png')
    plt.savefig(pls_da_plot_path)
    plt.close()

    # Plotting the loadings (feature contributions)
    loadings = pls_da.x_loadings_

    # Sort loadings by their magnitude
    sorted_indices = np.argsort(np.abs(loadings[:, 0]))[::-1]
    top_n = 20  # Number of top metabolites to display
    top_indices = sorted_indices[:top_n]

    # Save the top 20 metabolites in a NumPy array
    top_metabolites_array = np.array([X.columns[i] for i in top_indices])

    plt.figure(figsize=(12, 8))
    for i in top_indices:
        plt.arrow(0, 0, loadings[i, 0], loadings[i, 1], color='r', alpha=0.5)
        plt.text(loadings[i, 0], loadings[i, 1], X.columns[i], fontsize=12, ha='center', va='center')

    plt.xlabel('PLS Component 1')
    plt.ylabel('PLS Component 2')
    plt.title('PLS-DA Loadings Plot (Top 20 Metabolite Contributions)')
    plt.grid()
    print("Top 20 Metabolites:", top_metabolites_array)
    # Adjust plot limits
    plt.xlim(loadings[:, 0].min() - 0.01, loadings[:, 0].max() + 0.01)
    plt.ylim(loadings[:, 1].min() - 0.01, loadings[:, 1].max() + 0.01)

    top_metabolites_plot_path = os.path.join(output_path, 'Top_20_Metabolites_plot.png')
    plt.savefig(top_metabolites_plot_path)
    plt.close()

    # Save the top 20 metabolites to a CSV file
    top_metabolites_csv_path = os.path.join(output_path, 'Top_20_Metabolites.csv')
    top_metabolites_df = pd.DataFrame(top_metabolites_array, columns=['Top Metabolites'])
    top_metabolites_df.to_csv(top_metabolites_csv_path, index=False)

    # ROC curve
    fpr, tpr, _ = roc_curve(y_test, y_pred)
    roc_auc = roc_auc_score(y_test, y_pred)

    plt.figure(figsize=(10, 7))
    plt.plot(fpr, tpr, color='blue', lw=2, label=f'ROC curve (area = {roc_auc:.2f})')
    plt.plot([0, 1], [0, 1], color='gray', lw=2, linestyle='--')
    plt.xlabel('False Positive Rate')
    plt.ylabel('True Positive Rate')
    plt.title('Receiver Operating Characteristic (ROC) Curve')
    plt.legend(loc='lower right')
    roc_curve_path = os.path.join(output_path, 'ROC_curve.png')
    plt.savefig(roc_curve_path)
    plt.close()

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 7:
        print("Usage: PLS-Da.py <meta_file_path> <file_path> <sheet> <output_path> <column> <conditions>")
        sys.exit(1)

    meta_file_path = sys.argv[1]
    file_path = sys.argv[2]
    sheet = sys.argv[3]
    output_path = sys.argv[4]
    column = sys.argv[5]
    conditions = sys.argv[6].split(',')

    main(meta_file_path, file_path, sheet, output_path, column, conditions)
