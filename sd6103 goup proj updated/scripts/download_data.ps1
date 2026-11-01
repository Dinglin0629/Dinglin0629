$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$raw = Join-Path $root 'data\raw'
New-Item -ItemType Directory -Force $raw | Out-Null

Invoke-WebRequest `
  -Uri 'https://raw.githubusercontent.com/BlueSkyLT/siteselect_sg/main/dataset/hdb.csv' `
  -OutFile (Join-Path $raw 'hdb.csv')

function Get-DataGovSgCsv([string]$datasetId, [string]$outputName) {
  $endpoint = "https://api-open.data.gov.sg/v1/public/api/datasets/$datasetId/poll-download"
  for ($attempt = 1; $attempt -le 6; $attempt++) {
    $response = Invoke-RestMethod -Uri $endpoint
    if ($response.code -ne 24) { break }
    Start-Sleep -Seconds 12
  }
  if ($response.code -ne 0 -or $response.data.status -ne 'DOWNLOAD_SUCCESS') {
    throw "Download request failed for $datasetId"
  }
  Invoke-WebRequest -Uri $response.data.url -OutFile (Join-Path $raw $outputName)
  Start-Sleep -Seconds 12
}

# Official Government Markets/Hawker Centres attributes.
Get-DataGovSgCsv 'd_68a42f09f350881996d83f9cd73ab02f' 'hawker_attributes.csv'
Get-DataGovSgCsv 'd_ebc5ab87086db484f88045b47411ebc5' 'resale_1990_1999.csv'
Get-DataGovSgCsv 'd_43f493c6c50d54243cc1eab0df142d6a' 'resale_2000_2012.csv'
Get-DataGovSgCsv 'd_2d5ff9ea31397b66239f245f57751537' 'resale_2012_2014.csv'
Get-DataGovSgCsv 'd_ea9ed51da2787afaf8e51f827c304208' 'resale_2015_2016.csv'
Get-DataGovSgCsv 'd_8b84c4ee58e3cfc0ece0d773c8ca6abc' 'resale_2017_present.csv'
