# Miami Climate Trap GIS-MCDM

This repository contains the MATLAB code, figure outputs, and data-source documentation associated with the study:

**Siting Coastal Water Reuse Infrastructure Under Sea-Level Rise: A Spatiotemporal GIS-MCDM Framework for Identifying the Climate Trap**

## Repository Contents

- `code/`  
  Contains the MATLAB analysis code.

- `figures/`  
  Contains the final figures generated for the manuscript.

- `data/`  
  Contains documentation describing the required datasets, original sources, file names, and expected folder structure.


## Main Analysis Code

The main MATLAB script is:

`code/Master_Script.m`

The script performs the GIS-MCDM analysis used to evaluate climate-resilient siting opportunities for water reuse infrastructure in Miami-Dade County, Florida.

The workflow includes:

- elevation-based slope analysis
- land-use suitability reclassification
- distance-to-demand analysis
- sea-level-rise climate veto
- suitability mapping
- climate-trap identification
- morphological filtering of candidate sites
- proximity and sensitivity analyses

## Data

The analysis uses publicly available geospatial datasets from:

- U.S. Geological Survey (USGS) 3DEP
- National Land Cover Database (NLCD)
- NOAA Office for Coastal Management
- U.S. Census Bureau TIGER/Line

Because the original geospatial datasets are very large, they are not stored directly in this GitHub repository.

See:

`data/README_DATA.md`

for the exact dataset names, official download sources, and folder structure expected by the MATLAB code.

## Software

The analysis was developed in MATLAB.

Users should download the required datasets and organize them according to the folder structure described in `data/README_DATA.md` before running the MATLAB script.

## Study Area

Miami-Dade County, Florida, USA.

## Purpose

This repository is provided to support transparency, reproducibility, and open access to the computational workflow associated with the study.
