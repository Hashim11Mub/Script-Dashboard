import streamlit as st
import os
import subprocess
import pandas as pd
from glob import glob

def validate_uploaded_files(files):
    """
    Validate if the uploaded files contain the required filenames.
    """
    required_files = ["META_EnvironmentalData.xlsx", "CTDlist010623.rds", "EnvMon_AllSites.xlsx"]
    uploaded_filenames = [file.name for file in files]
    
    missing_files = [file for file in required_files if file not in uploaded_filenames]
    
    if missing_files:
        return False, f"Missing required files: {', '.join(missing_files)}"
    
    return True, "All required files are uploaded"

st.title("Python Script Dashboard")

# File uploader section for required files
st.header("Upload Data Files")
uploaded_files = st.file_uploader("Upload the required data files", type=["xlsx", "rds"], accept_multiple_files=True)

# Validate the uploaded files
if uploaded_files:
    is_valid, message = validate_uploaded_files(uploaded_files)
    if is_valid:
        st.success(message)
        # Save the uploaded files to a temporary directory
        data_directory = "uploaded_data/"
        if not os.path.exists(data_directory):
            os.makedirs(data_directory)
        
        for uploaded_file in uploaded_files:
            with open(os.path.join(data_directory, uploaded_file.name), "wb") as f:
                f.write(uploaded_file.getbuffer())
        
        st.write(f"Data files saved to: {data_directory}")
    else:
        st.warning(message)

# Script upload section
st.header("Upload and Manage Python Scripts")
uploaded_script = st.file_uploader("Upload your Python script", type="py")

if uploaded_script is not None:
    script_storage = "scripts/"
    if not os.path.exists(script_storage):
        os.makedirs(script_storage)
    
    script_path = os.path.join(script_storage, uploaded_script.name)
    with open(script_path, "wb") as f:
        f.write(uploaded_script.getbuffer())
    st.success(f"Uploaded script: {uploaded_script.name}")
    st.write(f"Script saved to: {script_path}")

# Select the script to run
scripts = os.listdir("scripts/")
selected_script = st.selectbox("Select a script to run", scripts)

if selected_script:
    st.write(f"Selected script: {selected_script}")

# Running the Script and Displaying Outputs
st.header("Run Script and View Results")

if st.button("Run Script"):
    if not uploaded_files:
        st.error("Cannot run script. No data files uploaded.")
    else:
        script_path = os.path.join("scripts", selected_script)
        
        st.write(f"Running script: {script_path}")
        
        if not os.path.exists(script_path):
            st.error(f"Script not found: {script_path}")
        else:
            try:
                # Running the Python script using subprocess
                result = subprocess.run(["python", script_path], 
                                        capture_output=True, 
                                        text=True, 
                                        check=True, 
                                        env=dict(os.environ, DATA_DIRECTORY=data_directory))
                st.write("Script executed successfully!")
                st.text(result.stdout)
            except subprocess.CalledProcessError as e:
                st.error(f"Error running script: {e.stderr}")
            except FileNotFoundError:
                st.error("Python executable not found. Please ensure Python is installed and in the PATH.")
            except Exception as e:
                st.error(f"An unexpected error occurred: {str(e)}")

# Visualize Script Outputs
st.header("Visualize Script Outputs")

if uploaded_files:
    output_files = glob(os.path.join(data_directory, "*"))
    st.write(f"Found {len(output_files)} output files.")

    for file in output_files:
        st.write(f"Processing file: {file}")
        if file.endswith((".jpeg", ".png")):
            st.image(file)
        elif file.endswith(".csv"):
            df = pd.read_csv(file)
            st.dataframe(df)
        elif file.endswith(".xlsx"):
            df = pd.read_excel(file)
            st.dataframe(df)
else:
    st.warning("Cannot display output files. No data files uploaded.")

# Script Persistence and Change Management
st.header("Script Change Management")

if st.checkbox("Admin Mode"):
    st.subheader("Manage Scripts")
    script_to_delete = st.selectbox("Select a script to delete", scripts)
    if st.button("Delete Script"):
        os.remove(os.path.join("scripts", script_to_delete))
        st.success(f"Deleted script: {script_to_delete}")