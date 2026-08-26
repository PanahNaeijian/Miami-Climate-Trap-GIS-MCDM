# Data Sources and Folder Structure

This repository uses publicly available geospatial datasets from USGS, MRLC/NLCD, NOAA, and the U.S. Census Bureau.

The large raw datasets are not stored directly in this GitHub repository. Instead, users should download them from the official sources listed below and place them in the folder structure expected by the MATLAB script.

## Required Folder Structure

Dataset/
├── 1-Elevation (DEM)/
│   └── USGS_13_n26w081_20231221.tif
├── 2-Land Use/
│   ├── Annual_NLCD_LndCov_2021_CU_C1V1.tif
│   └── LandUse_Miami_Aligned.tif
├── 3-Sea Level Rise/
│   ├── FL_SE_slr_depth_1_0ft.tif
│   ├── FL_SE_slr_depth_3_0ft.tif
│   ├── SLR_Miami_Aligned.tif
│   ├── SLR_Miami_Aligned_Low.tif
│   └── SLR_Miami_Aligned_Extreme.tif
└── 4-Roads_Infrastructure/
    └── tl_2024_12_prisecroads.*

## 1. Elevation (DEM)

Source: U.S. Geological Survey (USGS) 3D Elevation Program (3DEP)

File used:
`USGS_13_n26w081_20231221.tif`

Official download:
https://prd-tnm.s3.amazonaws.com/index.html?prefix=StagedProducts/Elevation/13/TIFF/historical/n26w081/

Alternative USGS portal:
https://apps.nationalmap.gov/downloader/

## 2. Land Use

Source: Multi-Resolution Land Characteristics Consortium (MRLC)

Dataset:
Annual National Land Cover Database (NLCD), 2021

Raw file:
`Annual_NLCD_LndCov_2021_CU_C1V1.tif`

Official source:
https://www.mrlc.gov/data

The MATLAB workflow references the processed file:
`LandUse_Miami_Aligned.tif`

## 3. Sea Level Rise

Source: NOAA Office for Coastal Management

Raw files used include:
`FL_SE_slr_depth_1_0ft.tif`
`FL_SE_slr_depth_3_0ft.tif`

Official NOAA Sea Level Rise data:
https://coast.noaa.gov/slrdata/

The MATLAB workflow references:
`SLR_Miami_Aligned.tif`
`SLR_Miami_Aligned_Low.tif`
`SLR_Miami_Aligned_Extreme.tif`

Technical reference:
Sweet et al. (2022), Global and Regional Sea Level Rise Scenarios for the United States.

https://tidesandcurrents.noaa.gov/publications/techrpt83_Global_and_Regional_SLR_Scenarios_for_the_US_final.pdf

## 4. Roads and Infrastructure

Source: U.S. Census Bureau TIGER/Line Shapefiles

File:
`tl_2024_12_prisecroads.zip`

Official source:
https://www2.census.gov/geo/tiger/TIGER2024/PRISECROADS/

For Florida, use state FIPS code 12:
`tl_2024_12_prisecroads.zip`

## Notes

The raw datasets are large and are therefore not included directly in this repository.

Users should download the datasets from the official sources above and place them in the folder structure shown before running the MATLAB script.

Some processed raster files are referenced by the MATLAB workflow using the suffix `_Aligned`.