import streamlit as st
import os
import subprocess
import pandas as pd
from glob import glob
import platform

def explore_directory(path):
    """
    Explore the given directory and return information about its contents.
    """
    try:
        contents = os.listdir(path)
        return f"Directory contents: {contents}"
    except Exception as e:
        return f"Error exploring directory: {str(e)}"

def validate_directory(directory):
    """
    Validate if the directory exists and contains the required files.
    """
    if not os.path.exists(directory):
        return False, f"Directory does not exist. Current working directory: {os.getcwd()}"
    
    required_files = ["META_EnvironmentalData.xlsx", "CTDlist010623.rds", "EnvMon_AllSites.xlsx"]
    missing_files = [file for file in required_files if not os.path.exists(os.path.join(directory, file))]
    
    if missing_files:
        return False, f"Missing required files: {', '.join(missing_files)}"
    
    return True, "Directory is valid and contains all required files"

st.title("Python Script Dashboard")

# Display system information
st.write(f"Operating System: {platform.system()} {platform.release()}")
st.write(f"Python Version: {platform.python_version()}")
st.write(f"Current working directory: {os.getcwd()}")
st.write(f"User home directory: {os.path.expanduser('~')}")

# List available drives (for Windows)
if platform.system() == "Windows":
    import win32api
    drives = win32api.GetLogicalDriveStrings()
    drives = drives.split('\000')[:-1]
    st.write(f"Available drives: {drives}")

# Set the directory where the data is located
data_directory = st.text_input("Enter the directory for data files", "M:/SEZ DES/Science and Monitoring (SM)/Workstreams/Environmental Monitoring/Marine/001DATA")

# Validate the directory
is_valid, message = validate_directory(data_directory)

if is_valid:
    st.success(message)
else:
    st.error(message)
    st.write(explore_directory(os.path.dirname(data_directory)))

    # Offer alternative input methods
    st.write("Alternative directory input methods:")
    use_file_uploader = st.checkbox("Use file uploader to navigate to the directory")
    if use_file_uploader:
        uploaded_file = st.file_uploader("Upload any file from the target directory", type=["xlsx", "csv", "txt"])
        if uploaded_file:
            data_directory = os.path.dirname(uploaded_file.name)
            st.write(f"New data directory: {data_directory}")

    use_parts = st.checkbox("Enter directory parts separately")
    if use_parts:
        parts = []
        for i in range(5):  # Allow up to 5 parts
            part = st.text_input(f"Directory part {i+1}")
            if part:
                parts.append(part)
            else:
                break
        if parts:
            data_directory = os.path.join(*parts)
            st.write(f"New data directory: {data_directory}")

override = st.checkbox("Override directory validation")
if override:
    is_valid = True
    st.warning("Directory validation overridden. Proceed with caution.")

st.write(f"Final data directory: {data_directory}")

# Set the script storage path
script_storage = "scripts/"
if not os.path.exists(script_storage):
    os.makedirs(script_storage)

# Script upload section
st.header("Upload and Manage Python Scripts")
uploaded_file = st.file_uploader("Upload your Python script", type="py")

if uploaded_file is not None:
    script_path = os.path.join(script_storage, uploaded_file.name)
    with open(script_path, "wb") as f:
        f.write(uploaded_file.getbuffer())
    st.success(f"Uploaded script: {uploaded_file.name}")
    st.write(f"Script saved to: {script_path}")

# Select the script to run
scripts = os.listdir(script_storage)
selected_script = st.selectbox("Select a script to run", scripts)

if selected_script:
    st.write(f"Selected script: {selected_script}")

# Running the Script and Displaying Outputs
st.header("Run Script and View Results")

if st.button("Run Script"):
    if not is_valid and not override:
        st.error("Cannot run script. The data directory is not valid.")
    else:
        script_path = os.path.join(script_storage, selected_script)
        
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

if is_valid or override:
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
    st.warning("Cannot display output files. The data directory is not valid.")

# Script Persistence and Change Management
st.header("Script Change Management")

if st.checkbox("Admin Mode"):
    st.subheader("Manage Scripts")
    script_to_delete = st.selectbox("Select a script to delete", scripts)
    if st.button("Delete Script"):
        os.remove(os.path.join(script_storage, script_to_delete))
        st.success(f"Deleted script: {script_to_delete}")