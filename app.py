import streamlit as st
import os
import subprocess
import pandas as pd
from glob import glob

##############################################################################################################
# File Upload and Script Management

st.title("R Script Dashboard")

# Set the directory where the data is located
data_directory = st.text_input("Enter the directory for data files", "M:/SEZ DES/Science and Monitoring (SM)/Workstreams/Environmental Monitoring/Marine/001DATA")

st.write(f"Data directory: {data_directory}")

# Set the script storage path
script_storage = "scripts/"
if not os.path.exists(script_storage):
    os.makedirs(script_storage)

# Script upload section
st.header("Upload and Manage R Scripts")
uploaded_file = st.file_uploader("Upload your R script", type="R")

if uploaded_file is not None:
    # Save the uploaded script
    with open(os.path.join(script_storage, uploaded_file.name), "wb") as f:
        f.write(uploaded_file.getbuffer())
    st.success(f"Uploaded script: {uploaded_file.name}")

# Select the script to run
scripts = os.listdir(script_storage)
selected_script = st.selectbox("Select a script to run", scripts)

if selected_script:
    st.write(f"Selected script: {selected_script}")

##############################################################################################################
# Running the Script and Displaying Outputs

st.header("Run Script and View Results")

# Button to run the selected script
if st.button("Run Script"):
    script_path = os.path.join(script_storage, selected_script)
    
    st.write(f"Running script: {script_path}")
    
    if not os.path.exists(script_path):
        st.error(f"Script not found: {script_path}")
    else:
        try:
            # Running the R script using subprocess
            result = subprocess.run(["Rscript", script_path], capture_output=True, text=True, check=True)
            st.write("Script executed successfully!")
            st.text(result.stdout)
        except subprocess.CalledProcessError as e:
            st.error(f"Error running script: {e.stderr}")
        except FileNotFoundError:
            st.error("Rscript executable not found. Please ensure R is installed and Rscript is in the PATH.")
        except Exception as e:
            st.error(f"An unexpected error occurred: {str(e)}")

##############################################################################################################
# Visualize Script Outputs

st.header("Visualize Script Outputs")

# Display any output files generated by the script
output_files = glob(os.path.join(data_directory, "*"))

st.write(f"Found {len(output_files)} output files.")

for file in output_files:
    st.write(f"Processing file: {file}")
    if file.endswith(".jpeg") or file.endswith(".png"):
        st.image(file)
    elif file.endswith(".csv"):
        df = pd.read_csv(file)
        st.dataframe(df)
    elif file.endswith(".xlsx"):
        df = pd.read_excel(file)
        st.dataframe(df)
    # Add other file types if necessary

##############################################################################################################
# Script Persistence and Change Management

st.header("Script Change Management")

# Admin panel to update or remove scripts
if st.checkbox("Admin Mode"):
    st.subheader("Manage Scripts")

    # Option to remove scripts
    script_to_delete = st.selectbox("Select a script to delete", scripts)
    if st.button("Delete Script"):
        os.remove(os.path.join(script_storage, script_to_delete))
        st.success(f"Deleted script: {script_to_delete}")