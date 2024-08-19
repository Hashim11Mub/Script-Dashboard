import streamlit as st
import os
import subprocess
import pandas as pd
from glob import glob

# Directory to store uploaded scripts and data files
script_storage = "scripts/"
data_storage = "uploaded_data/"

# Create directories if they don't exist
if not os.path.exists(script_storage):
    os.makedirs(script_storage)

if not os.path.exists(data_storage):
    os.makedirs(data_storage)

def get_uploaded_scripts():
    """Return a list of uploaded scripts."""
    return os.listdir(script_storage)

def delete_script(script_name):
    """Delete the specified script."""
    script_path = os.path.join(script_storage, script_name)
    if os.path.exists(script_path):
        os.remove(script_path)
        return f"Deleted script: {script_name}"
    else:
        return f"Script {script_name} not found."

def save_uploaded_file(uploaded_file, storage_directory):
    """Save an uploaded file to the specified directory."""
    file_path = os.path.join(storage_directory, uploaded_file.name)
    with open(file_path, "wb") as f:
        f.write(uploaded_file.getbuffer())
    return file_path

# Title of the app
st.title("Python Script and Data Dashboard")

# File uploader for data files
st.header("Upload and Manage Data Files")
uploaded_data_file = st.file_uploader("Upload your data file", type=["csv", "xlsx", "rds"])

if uploaded_data_file is not None:
    data_file_path = save_uploaded_file(uploaded_data_file, data_storage)
    st.success(f"Uploaded data file: {uploaded_data_file.name}")
    st.write(f"Data file saved to: {data_file_path}")

# Display uploaded data files
st.header("Uploaded Data Files")
uploaded_data_files = os.listdir(data_storage)
if uploaded_data_files:
    for data_file in uploaded_data_files:
        st.write(data_file)
else:
    st.write("No data files uploaded yet.")

# File uploader for Python scripts
st.header("Upload and Manage Python Scripts")
uploaded_file = st.file_uploader("Upload your Python script", type="py")

if uploaded_file is not None:
    script_path = save_uploaded_file(uploaded_file, script_storage)
    st.success(f"Uploaded script: {uploaded_file.name}")
    st.write(f"Script saved to: {script_path}")

# Display uploaded scripts and options to run or delete them
st.header("Manage Uploaded Scripts")

uploaded_scripts = get_uploaded_scripts()

if uploaded_scripts:
    selected_script = st.selectbox("Select a script to run or delete", uploaded_scripts)

    # Run the selected script
    if st.button("Run Script"):
        script_path = os.path.join(script_storage, selected_script)
        st.write(f"Running script: {script_path}")
        
        try:
            result = subprocess.run(["python", script_path], capture_output=True, text=True, check=True)
            st.write("Script executed successfully!")
            st.text(result.stdout)
        except subprocess.CalledProcessError as e:
            st.error(f"Error running script: {e.stderr}")
        except FileNotFoundError:
            st.error("Python executable not found. Please ensure Python is installed and in the PATH.")
        except Exception as e:
            st.error(f"An unexpected error occurred: {str(e)}")

    # Delete the selected script
    if st.button("Delete Script"):
        message = delete_script(selected_script)
        st.warning(message)
else:
    st.write("No scripts uploaded yet.")

# Add more sections to your app as needed