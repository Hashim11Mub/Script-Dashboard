import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import geopandas as gpd
import folium
from streamlit_folium import folium_static

# Load data
@st.cache_data
def load_data():
    ctd_files = ['RSP_EM_ABL003_CTD_20220623_Cast.csv', 'RSP_EM_ABL004_CTD_20220623_Cast (1).csv']
    ctd_data = []
    for file in ctd_files:
        df = pd.read_csv(file)
        df['File'] = file
        ctd_data.append(df)
    combined_ctd = pd.concat(ctd_data, ignore_index=True)
    env_mon_sites = pd.read_excel("EnvMon_AllSites.xlsx")
    return combined_ctd, env_mon_sites

combined_ctd, env_mon_sites = load_data()

# Streamlit app
st.title('CTD Data Analysis Dashboard')

# Sidebar for navigation
page = st.sidebar.selectbox("Choose a page", ["Overview", "Temperature Analysis", "Salinity Analysis", "Site Map"])

if page == "Overview":
    st.header("Data Overview")
    st.write("CTD Data Sample:")
    st.dataframe(combined_ctd.head())
    st.write("Environmental Monitoring Sites Sample:")
    st.dataframe(env_mon_sites.head())

elif page == "Temperature Analysis":
    st.header("Temperature vs Depth Analysis")
    fig, ax = plt.subplots(figsize=(10, 6))
    for file in combined_ctd['File'].unique():
        data = combined_ctd[combined_ctd['File'] == file]
        ax.scatter(data['Temp °C'], data['Depth m'], label=file)
    ax.set_xlabel('Temperature (°C)')
    ax.set_ylabel('Depth (m)')
    ax.set_title('Temperature vs Depth')
    ax.legend()
    ax.invert_yaxis()
    st.pyplot(fig)

elif page == "Salinity Analysis":
    st.header("Salinity vs Depth Analysis")
    fig, ax = plt.subplots(figsize=(10, 6))
    for file in combined_ctd['File'].unique():
        data = combined_ctd[combined_ctd['File'] == file]
        ax.scatter(data['Sal psu'], data['Depth m'], label=file)
    ax.set_xlabel('Salinity (psu)')
    ax.set_ylabel('Depth (m)')
    ax.set_title('Salinity vs Depth')
    ax.legend()
    ax.invert_yaxis()
    st.pyplot(fig)

elif page == "Site Map":
    st.header("Monitoring Sites Map")
    if 'Latitude' in env_mon_sites.columns and 'Longitude' in env_mon_sites.columns:
        m = folium.Map(location=[env_mon_sites['Latitude'].mean(), env_mon_sites['Longitude'].mean()], zoom_start=10)
        for idx, row in env_mon_sites.iterrows():
            folium.Marker([row['Latitude'], row['Longitude']], popup=row['SiteName']).add_to(m)
        folium_static(m)
    else:
        st.write("Latitude and Longitude data not available in the Environmental Monitoring Sites file.")

# You can add more pages and visualizations as needed

st.sidebar.info("This dashboard provides analysis of CTD data and environmental monitoring sites.")