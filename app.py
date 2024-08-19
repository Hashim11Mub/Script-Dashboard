import streamlit as st
import pandas as pd
import os

def process_uploaded_files(files):
    """
    Process the uploaded files and return their paths.
    """
    if not files:
        st.error("No files uploaded!")
        return None
    
    file_paths = {}
    
    for uploaded_file in files:
        file_path = os.path.join("uploaded_data", uploaded_file.name)
        with open(file_path, "wb") as f:
            f.write(uploaded_file.getbuffer())
        file_paths[uploaded_file.name] = file_path
    
    return file_paths

st.title("Python Script Dashboard")

# File upload section for required data files
st.header("Upload Required Data Files")
uploaded_files = st.file_uploader("Upload required data files", type=["xlsx", "rds"], accept_multiple_files=True)

if uploaded_files:
    file_paths = process_uploaded_files(uploaded_files)
    if file_paths:
        st.success("All required files are uploaded")

# Script upload section
st.header("Upload and Manage Python Scripts")
uploaded_script = st.file_uploader("Upload your Python script", type="py")

if uploaded_script:
    script_path = os.path.join("scripts", uploaded_script.name)
    with open(script_path, "wb") as f:
        f.write(uploaded_script.getbuffer())
    st.success(f"Uploaded script: {uploaded_script.name}")
    st.write(f"Script saved to: {script_path}")

# Select the script to run
if 'scripts' in os.listdir():
    scripts = os.listdir('scripts')
else:
    scripts = []
selected_script = st.selectbox("Select a script to run", scripts)

if selected_script:
    st.write(f"Selected script: {selected_script}")

# Running the Script and Displaying Outputs
st.header("Run Script and View Results")

if st.button("Run Script"):
    if not file_paths:
        st.error("Cannot run script. No data files uploaded.")
    else:
        try:
            # Running the Python script using subprocess
            result = subprocess.run(["python", os.path.join("scripts", selected_script)], 
                                    capture_output=True, 
                                    text=True, 
                                    check=True, 
                                    env=dict(os.environ, **file_paths))
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

if file_paths:
    for file_name, file_path in file_paths.items():
        st.write(f"Processing file: {file_name}")
        if file_name.endswith((".jpeg", ".png")):
            st.image(file_path)
        elif file_name.endswith(".csv"):
            df = pd.read_csv(file_path)
            st.dataframe(df)
        elif file_name.endswith(".xlsx"):
            df = pd.read_excel(file_path)
            st.dataframe(df)
else:
    st.warning("Cannot display output files. No data files uploaded.")