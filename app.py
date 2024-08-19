import streamlit as st
import pandas as pd
import io

st.title('CTD Data Analysis Dashboard')

# File upload section
st.sidebar.header("Upload Data Files")
ctd_file1 = st.sidebar.file_uploader("Upload CTD File 1 (CSV)", type="csv")
ctd_file2 = st.sidebar.file_uploader("Upload CTD File 2 (CSV)", type="csv")
env_mon_file = st.sidebar.file_uploader("Upload Environmental Monitoring Sites File (Excel)", type="xlsx")

# Load data
@st.cache_data
def load_data(ctd_file1, ctd_file2, env_mon_file):
    ctd_data = []
    if ctd_file1 is not None:
        df1 = pd.read_csv(ctd_file1)
        df1['File'] = ctd_file1.name
        ctd_data.append(df1)
    if ctd_file2 is not None:
        df2 = pd.read_csv(ctd_file2)
        df2['File'] = ctd_file2.name
        ctd_data.append(df2)
    
    combined_ctd = pd.concat(ctd_data, ignore_index=True) if ctd_data else pd.DataFrame()
    
    env_mon_sites = pd.DataFrame()
    if env_mon_file is not None:
        try:
            env_mon_sites = pd.read_excel(env_mon_file)
        except ImportError:
            st.error("Unable to read Excel file. Please install openpyxl or convert the file to CSV.")
            st.info("To install openpyxl, run: pip install openpyxl")
            env_mon_sites = pd.DataFrame()
    
    return combined_ctd, env_mon_sites

# Only process data if files are uploaded
if ctd_file1 is not None and ctd_file2 is not None and env_mon_file is not None:
    combined_ctd, env_mon_sites = load_data(ctd_file1, ctd_file2, env_mon_file)

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
        if not env_mon_sites.empty and 'Latitude' in env_mon_sites.columns and 'Longitude' in env_mon_sites.columns:
            st.dataframe(env_mon_sites[['SiteName', 'Latitude', 'Longitude']])
        else:
            st.write("Latitude and Longitude data not available in the Environmental Monitoring Sites file.")

    st.sidebar.info("This dashboard provides analysis of CTD data and environmental monitoring sites.")

else:
    st.write("Please upload all required files using the sidebar to view the analysis.")