<#
.SYNOPSIS
Exports results of a KQL query from an Azure Log Analytics workspace, splitting the export into batches by a specified number of minutes. Results can be organized into folders by year, month, day, or hour.

.DESCRIPTION
This script connects to an Azure Log Analytics workspace and exports the results of a provided KQL query.
The export is performed in time-based batches, with each batch covering a specified number of minutes.
Output files are organized into folders based on the chosen time split (year, month, day, or hour).
This is useful for exporting large datasets in manageable chunks for backup, analysis, or migration.

.EXAMPLE
$query = @"
InsightsMetrics
| where Computer == "azvm-uan-01"
"@
$params = @{
    StartDate    = '2025-08-18'
    FinalDate    = '2025-09-01'
    ExportFolder = "C:\LogExports"
    NamePrefix = "InsightsMetrics"
    KqlQuery = $query
    WorkspaceId = "a1dac7ee-0d6c-47e3-a7b8-cb96ac16af47"
    SplitBy = "month"
    minutesPerBatch = 60
}
.\LogAnalyticsExportTable.ps1 @Params -verbose

.NOTES
Author: WMOSELHY

.LINK

#>

[CmdletBinding()]
param (
    # Start date and time for the export range.
    [datetime]$StartDate,

    # End date and time for the export range.
    [datetime]$FinalDate,

    # The Kusto Query Language (KQL) query to run against the Log Analytics workspace. Please supply as a here-string for multi-line queries.
    [string]$KqlQuery,

    # Azure Log Analytics workspace ID.
    [string] $WorkspaceId,

    # Path to the folder where exported files will be saved.
    [string] $ExportFolder,

    # Prefix for the names of the exported files.
    [string] $NamePrefix,

    # Specifies how to organize output folders. Valid values are 'year', 'month', 'day', or 'hour'. Default is 'day'.
    [ValidateSet("Year", "Month", "Day", "Hour")]
    [string] $SplitBy = "day",

    # The number of minutes each export batch should cover. Default is 60.
    [int]$minutesPerBatch = 60
)

#requires -Module Az.OperationalInsights,PSFramework

function Add-BatchTimeFilter {
    param (
        [string]$KqlQuery,
        [datetime]$Start,
        [datetime]$End
    )

    $querySplit = $KqlQuery -split "`r`n"
    $batchFilter = "| where TimeGenerated between (datetime($($Start.ToString("o"))) .. datetime($($End.ToString("o"))))"
    if ( $querySplit.count -eq 1) {
        $batchQuery = (@($querySplit[0], $batchFilter)) -join "`r`n"
    }
    else {
        $batchQuery = (@($querySplit[0], $batchFilter) + $querySplit[1..($querySplit.Count - 1)]) -join "`r`n"
    }

    $batchQuery
}

# Set the initial start and end datetime

$currentStart = $StartDate
$rootPath = Join-Path -Path $ExportFolder -ChildPath $NamePrefix

#Setting up File Logging
$paramSetPSFLoggingProvider = @{
    Name         = 'logfile'
    InstanceName = 'LogAnalytics'
    FilePath     = "$rootPath\ProgressLog-%Date%_%hour%.csv"
    Enabled      = $true
    Wait         = $true
}
Set-PSFLoggingProvider @paramSetPSFLoggingProvider

# This part is for logging and troubleshooting only, showing an example of the query that will be used.
$currentEnd = $currentStart.AddMinutes($minutesPerBatch)

$exampleBatch = Add-BatchTimeFilter -KqlQuery $kqlQuery -Start $currentStart -End $currentEnd
Write-PSFMessage -Level Verbose -Message "First query as an example for troubleshooting: `r`n{0}" -StringValues $exampleBatch

do {
    $currentEnd = $currentStart.AddMinutes($minutesPerBatch)

    # setting folder name depending on split selection
    switch ($SplitBy) {
        "year" { $folderName = "$rootPath\$($currentStart.ToString("yyyy"))" }
        "month" { $folderName = "$rootPath\$($currentStart.ToString("yyyy-MM"))" }
        "day" { $folderName = "$rootPath\$($currentStart.ToString("yyyy-MM-dd"))" }
        "hour" { $folderName = "$rootPath\$($currentStart.ToString("yyyy-MM-dd_HH"))" }
        default { $folderName = $rootPath }

    }

    if (-not (Test-Path $folderName)) {
        $null = New-Item -Path $folderName -ItemType Directory
    }
    $fileName = "$folderName\{0}_{1}__{2}.json" -f $NamePrefix, $currentStart.ToString("yyyyMMdd_HH-mm-ss"), $currentEnd.ToString("yyyyMMdd_HH-mm-ss")
    $errorFileName = "$folderName\{0}_{1}__{2}_ERRORS.json" -f $NamePrefix, $currentStart.ToString("yyyyMMdd_HH-mm-ss"), $currentEnd.ToString("yyyyMMdd_HH-mm-ss")


    $batchQuery = Add-BatchTimeFilter -KqlQuery $kqlQuery -Start $currentStart -End $currentEnd

    Write-PSFMessage -Level Verbose -Message "Exporting data from $($currentStart.ToString()) to $($currentEnd.ToString()) to $fileName"

    try {
        $batchOutput = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $batchQuery -ErrorAction Stop
    }
    catch {
        Write-PSFMessage -Level Error -Message "Errors while running query saved to $errorFileName"
        $_ | Out-File -FilePath $errorFileName
    }


    $batchOutput.Results | ConvertTo-Json -Depth 99 | Out-File -FilePath $fileName

    if ($batchOutput.Error) {
        $batchOutput.Error | ConvertTo-Json -Depth 99 | Out-File -FilePath $errorFileName
        Write-PSFMessage -Level Error -Message "Errors while running query saved to $errorFileName"
    }

    $currentStart = $currentEnd
}
while ($currentEnd -lt $FinalDate)
