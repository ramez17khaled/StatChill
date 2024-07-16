# Use an official Python runtime as a parent image
FROM python:3.9

# Set the working directory in the container
WORKDIR /app

# Install necessary system dependencies
RUN apt-get update && apt-get install -y \
    r-base \
    r-base-dev \
    xvfb \
    xauth \
    libglu1-mesa \
    libx11-xcb1 \
    libgl1-mesa-glx \
    libgl1-mesa-dev \
    dos2unix \
    mesa-utils \
    pandoc \
    x11-apps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install R packages
RUN Rscript -e 'install.packages(c("dplyr", "tidyr", "readxl", "ggplot2", "ggrepel", "rgl", "htmlwidgets"), repos="https://cran.rstudio.com/")'

# Copy your scripts
COPY . .

# Convert line endings and set executable permissions
RUN dos2unix StatChill.sh GUI.py PLS-Da.py Volcano.R testing.py PCA.R batchCorrecting.R
RUN chmod +x StatChill.sh GUI.py PLS-Da.py Volcano.R testing.py PCA.R batchCorrecting.R

# Copy PCA analysis Rmd file to the appropriate directory
COPY pca_analysis.Rmd /app/test/pca_analysis.Rmd

# Setup X11 forwarding
ENV DISPLAY=:0

# Define the entry point for the container
ENTRYPOINT ["./StatChill.sh"]

# For headless operation using Xvfb
CMD ["xvfb-run", "--server-args='-screen 0 1024x768x24'",  "bash", "StatChill.sh"]

