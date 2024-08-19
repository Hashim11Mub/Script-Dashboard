import streamlit as st
import pandas as pd
import plotly.express as px
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
    fig = px.scatter(combined_ctd, x='Temp °C', y='Depth m', color='File',
                     labels={'Temp °C': 'Temperature (°C)', 'Depth m': 'Depth (m)'},
                     title='Temperature vs Depth')
    fig.update_yaxes(autorange="reversed")
    st.plotly_chart(fig)

elif page == "Salinity Analysis":
    st.header("Salinity vs Depth Analysis")
    fig = px.scatter(combined_ctd, x='Sal psu', y='Depth m', color='File',
                     labels={'Sal psu': 'Salinity (psu)', 'Depth m': 'Depth (m)'},
                     title='Salinity vs Depth')
    fig.update_yaxes(autorange="reversed")
    st.plotly_chart(fig)

elif page == "Site Map":
    st.header("Monitoring Sites Map")
    if 'Latitude' in env_mon_sites.columns and 'Longitude' in env_mon_sites.columns:
        m = folium.Map(location=[env_mon_sites['Latitude'].mean(), env_mon_sites['Longitude'].mean()], zoom_start=10)
        for idx, row in env_mon_sites.iterrows():
            folium.Marker([row['Latitude'], row['Longitude']], popup=row['SiteName']).add_to(m)
        folium_static(m)
    else:
        st.write("Latitude and Longitude data not available in the Environmental Monitoring Sites file.")

st.sidebar.info("This dashboard provides analysis of CTD data and environmental monitoring sites.")