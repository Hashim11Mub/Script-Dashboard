import streamlit as st
import pandas as pd
import io

st.title('CTD Data Analysis Dashboard')

# File upload section
st.sidebar.header("Upload Data Files")
ctd_file1 = st.sidebar.file_uploader("Upload CTD File 1", type=["csv", "xlsx", "xls"])
ctd_file2 = st.sidebar.file_uploader("Upload CTD File 2", type=["csv", "xlsx", "xls"])
env_mon_file = st.sidebar.file_uploader("Upload Environmental Monitoring Sites File", type=["csv", "xlsx", "xls"])

st.sidebar.info("Files will be automatically converted to CSV if necessary.")

def convert_to_csv(file):
    if file.name.endswith('.csv'):
        return pd.read_csv(file)
    elif file.name.endswith(('.xlsx', '.xls')):
        return pd.read_excel(file)
    else:
        raise ValueError(f"Unsupported file format: {file.name}")

# Load data
@st.cache_data
def load_data(ctd_file1, ctd_file2, env_mon_file):
    ctd_data = []
    for file in [ctd_file1, ctd_file2]:
        if file is not None:
            try:
                df = convert_to_csv(file)
                df['File'] = file.name
                ctd_data.append(df)
            except Exception as e:
                st.error(f"Error reading {file.name}: {str(e)}")
    
    combined_ctd = pd.concat(ctd_data, ignore_index=True) if ctd_data else pd.DataFrame()
    
    env_mon_sites = pd.DataFrame()
    if env_mon_file is not None:
        try:
            env_mon_sites = convert_to_csv(env_mon_file)
        except Exception as e:
            st.error(f"Error reading Environmental Monitoring Sites file: {str(e)}")
    
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
        if 'Latitude' in env_mon_sites.columns and 'Longitude' in env_mon_sites.columns:
            st.dataframe(env_mon_sites[['SiteName', 'Latitude', 'Longitude']])
        else:
            st.write("Latitude and Longitude data not available in the Environmental Monitoring Sites file.")

    st.sidebar.info("This dashboard provides analysis of CTD data and environmental monitoring sites.")

else:
    st.write("Please upload all required files using the sidebar to view the analysis.")