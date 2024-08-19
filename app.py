import streamlit as st
import pandas as pd
import io
import openpyxl

st.title('CTD Data Analysis Dashboard')

# File upload section
st.sidebar.header("Upload Data Files")
ctd_file1 = st.sidebar.file_uploader("Upload CTD File 1 (CSV or Excel)", type=["csv", "xlsx", "xls"])
ctd_file2 = st.sidebar.file_uploader("Upload CTD File 2 (CSV or Excel)", type=["csv", "xlsx", "xls"])
env_mon_file = st.sidebar.file_uploader("Upload Environmental Monitoring Sites File (CSV or Excel)", type=["csv", "xlsx", "xls"])

st.sidebar.info("You can upload either CSV or Excel files. Excel files will be automatically converted.")

def read_file(file):
    if file.name.lower().endswith(('.xlsx', '.xls')):
        # For Excel files
        wb = openpyxl.load_workbook(file)
        sheet = wb.active
        data = sheet.values
        columns = next(data)
        df = pd.DataFrame(data, columns=columns)
    else:
        # For CSV files
        df = pd.read_csv(file)
    return df

# Load data
@st.cache_data
def load_data(ctd_file1, ctd_file2, env_mon_file):
    ctd_data = []
    for file in [ctd_file1, ctd_file2]:
        if file is not None:
            try:
                df = read_file(file)
                df['File'] = file.name
                ctd_data.append(df)
            except Exception as e:
                st.error(f"Error reading {file.name}: {str(e)}")
    
    combined_ctd = pd.concat(ctd_data, ignore_index=True) if ctd_data else pd.DataFrame()
    
    env_mon_sites = pd.DataFrame()
    if env_mon_file is not None:
        try:
            env_mon_sites = read_file(env_mon_file)
        except Exception as e:
            st.error(f"Error reading Environmental Monitoring Sites file: {str(e)}")
    
    return combined_ctd, env_mon_sites

# Only process data if files are uploaded
if ctd_file1 is not None and ctd_file2 is not None and env_mon_file is not None:
    combined_ctd, env_mon_sites = load_data(ctd_file1, ctd_file2, env_mon_file)

    if not env_mon_sites.empty and not combined_ctd.empty:
        # Sidebar for navigation
        page = st.sidebar.selectbox("Choose a page", ["Overview", "Temperature Analysis", "Salinity Analysis", "Site Information"])

        if page == "Overview":
            st.header("Data Overview")
            st.write("CTD Data Sample:")
            st.dataframe(combined_ctd.head())
            st.write("Environmental Monitoring Sites Sample:")
            st.dataframe(env_mon_sites.head())

        elif page == "Temperature Analysis":
            st.header("Temperature vs Depth Analysis")
            if 'Depth m' in combined_ctd.columns and 'Temp °C' in combined_ctd.columns:
                st.line_chart(combined_ctd.groupby('Depth m')['Temp °C'].mean())
                st.write("This chart shows the average temperature at different depths.")
            else:
                st.write("Required columns 'Depth m' and 'Temp °C' not found in the data.")

        elif page == "Salinity Analysis":
            st.header("Salinity vs Depth Analysis")
            if 'Depth m' in combined_ctd.columns and 'Sal psu' in combined_ctd.columns:
                st.line_chart(combined_ctd.groupby('Depth m')['Sal psu'].mean())
                st.write("This chart shows the average salinity at different depths.")
            else:
                st.write("Required columns 'Depth m' and 'Sal psu' not found in the data.")

        elif page == "Site Information":
            st.header("Monitoring Sites Information")
            if 'Latitude' in env_mon_sites.columns and 'Longitude' in env_mon_sites.columns:
                st.dataframe(env_mon_sites[['SiteName', 'Latitude', 'Longitude']])
            else:
                st.write("Latitude and Longitude data not available in the Environmental Monitoring Sites file.")

        st.sidebar.info("This dashboard provides analysis of CTD data and environmental monitoring sites.")
    else:
        st.error("Failed to load data. Please check your files and try again.")
else:
    st.write("Please upload all required files using the sidebar to view the analysis.")