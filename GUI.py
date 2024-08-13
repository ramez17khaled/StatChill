import importlib.util
import subprocess
import sys

# List of required libraries
required_libraries = ['tkinter', 'pandas']

# Check if each library is installed
for lib in required_libraries:
    spec = importlib.util.find_spec(lib)
    if spec is None:
        print(f"{lib} is not installed. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", lib])

import tkinter as tk
from tkinter import filedialog, messagebox
import pandas as pd

class FilePathApp:
    def __init__(self, root):
        self.root = root
        self.root.title("StatChill")

        self.meta_file_path = tk.StringVar()
        self.file_path = tk.StringVar()
        self.sheet = tk.StringVar()
        self.output_path = tk.StringVar()
        self.method_var = tk.StringVar()
        self.column_var = tk.StringVar()
        self.label_column_var = tk.StringVar(value="") 
        self.conditions = tk.StringVar()

        tk.Label(root, text="MetaData File Path").grid(row=0, column=0)
        self.meta_entry = tk.Entry(root, width=50, textvariable=self.meta_file_path)
        self.meta_entry.grid(row=0, column=1)
        tk.Button(root, text="Browse", command=self.browse_meta).grid(row=0, column=2)

        tk.Label(root, text="Data File Path").grid(row=1, column=0)
        self.file_entry = tk.Entry(root, width=50, textvariable=self.file_path)
        self.file_entry.grid(row=1, column=1)
        tk.Button(root, text="Browse", command=self.browse_file).grid(row=1, column=2)

        tk.Label(root, text="Sheet/Page (Excel only)").grid(row=2, column=0)
        self.sheet_entry = tk.Entry(root, width=50, textvariable=self.sheet)
        self.sheet_entry.grid(row=2, column=1)

        tk.Label(root, text="Output Path").grid(row=3, column=0)
        self.output_entry = tk.Entry(root, width=50, textvariable=self.output_path)
        self.output_entry.grid(row=3, column=1)
        tk.Button(root, text="Browse", command=self.browse_output).grid(row=3, column=2)

        tk.Label(root, text="Statistical Method").grid(row=4, column=0)
        self.method_var.set("PCA")  # Default value
        self.methods = ["PCA", "sigDiff", "Volcano", "PLS-Da", "corrHeatmap","batchCorrect","repartition"]
        self.method_menu = tk.OptionMenu(root, self.method_var, *self.methods)
        self.method_menu.grid(row=4, column=1)

        tk.Label(root, text="Select Column of Interest").grid(row=5, column=0)
        self.column_menu = tk.OptionMenu(root, self.column_var, '')
        self.column_menu.grid(row=5, column=1)

        tk.Label(root, text="Select Label Column (Optional)").grid(row=6, column=0)
        self.label_column_menu = tk.OptionMenu(root, self.label_column_var, '')
        self.label_column_menu.grid(row=6, column=1)

        tk.Label(root, text="Enter Conditions (comma-separated)").grid(row=7, column=0)
        self.condition_entry = tk.Entry(root, width=50, textvariable=self.conditions)
        self.condition_entry.grid(row=7, column=1)

        tk.Button(root, text="Submit", command=self.submit).grid(row=8, columnspan=3)

        self.meta_entry.bind("<FocusOut>", self.update_columns)

    def browse_meta(self):
        file_path = filedialog.askopenfilename(filetypes=[("Excel files", "*.xlsx *.xls"), ("CSV files", "*.csv")])
        if file_path:
            self.meta_entry.delete(0, tk.END)
            self.meta_entry.insert(0, file_path)
            self.update_columns()

    def browse_file(self):
        file_path = filedialog.askopenfilename(filetypes=[("Excel files", "*.xlsx *.xls"), ("CSV files", "*.csv")])
        if file_path:
            self.file_entry.delete(0, tk.END)
            self.file_entry.insert(0, file_path)

    def browse_output(self):
        output_path = filedialog.askdirectory()
        if output_path:
            self.output_entry.delete(0, tk.END)
            self.output_entry.insert(0, output_path)

    def update_columns(self, event=None):
        meta_file_path = self.meta_entry.get()
        if not meta_file_path:
            return

        try:
            if meta_file_path.endswith(('.xlsx', '.xls')):
                meta_data = pd.read_excel(meta_file_path)
            elif meta_file_path.endswith('.csv'):
                meta_data = pd.read_csv(meta_file_path, sep=';')
            else:
                messagebox.showerror("Error", "Unsupported file format for Metadata file.")
                return

            columns = [col.lower().replace(' ', '_') for col in meta_data.columns]
            self.column_var.set(columns[0])
            self.label_column_var.set("")  
            menu = self.column_menu["menu"]
            menu.delete(0, "end")

            label_menu = self.label_column_menu["menu"]
            label_menu.delete(0, "end")

            for col in columns:
                menu.add_command(label=col, command=tk._setit(self.column_var, col))
                label_menu.add_command(label=col, command=tk._setit(self.label_column_var, col))

        except Exception as e:
            messagebox.showerror("Error", f"Failed to load Metadata: {e}")

    def submit(self):
        meta_file_path = self.meta_entry.get()
        file_path = self.file_entry.get()
        sheet = self.sheet_entry.get()
        output_path = self.output_entry.get()
        method = self.method_var.get()
        column = self.column_var.get()
        label_column = self.label_column_var.get() if self.label_column_var.get() else ""  
        conditions = self.conditions.get()

        if not all([meta_file_path, file_path, output_path, method]):
            messagebox.showerror("Error", "Please fill in all fields.")
            return

        try:
            with open('config.txt', 'w') as f:
                f.write(f"meta_file_path={meta_file_path}\n")
                f.write(f"file_path={file_path}\n")
                f.write(f"sheet={sheet}\n")
                f.write(f"output_path={output_path}\n")
                f.write(f"method={method}\n")
                f.write(f"column={column}\n")
                f.write(f"label_column={label_column}\n")  
                f.write(f"conditions={conditions}\n")

            messagebox.showinfo("Success", "Configuration saved. The batch file will now process the data.")
            self.root.quit()  
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save configuration: {e}")

if __name__ == "__main__":
    root = tk.Tk()
    app = FilePathApp(root)
    root.mainloop()
