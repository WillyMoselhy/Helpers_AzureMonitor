# Azure Monitor Toolkit

This repository provides scripts and utilities for working with Azure Monitor. It is designed to simplify common monitoring tasks, automate data collection, and streamline integration with Azure services.

## Repository Structure

| File/Folder                                             | Description                                                |
| ------------------------------------------------------- | ---------------------------------------------------------- |
| [LogAnalyticsExportTable.ps1](LogAnalyticsExportTable.ps1) | Exports data from Azure Log Analytics query to json files. |

## [LogAnalyticsExportTable.ps1](LogAnalyticsExportTable.ps1)

The primary script, LogAnalyticsExportTable.ps1, runs Kusto (KQL) queries against a Log Analytics workspace and exports results into time‑based batches. Exports can be saved as JSON files and organized into a predictable folder hierarchy (by year, month, day, or hour) to simplify downstream processing, archival, or migration.

Key capabilities

- Run any KQL query against an Azure Log Analytics workspace and export results to disk.
- Split large exports into time‑bounded batches so each file covers a fixed interval (configurable minutes per batch).
- Organize output into folders based on time (Year, Month, Day, Hour) for easier navigation and automated ingestion.
- Produce separate files for results and errors so failed batches are easy to find and re-run.
- Verbose and file-based logging to support troubleshooting and incremental processing.

Why use this tool

- Avoids long-running single queries by breaking exports into manageable chunks that are less likely to time out or consume excessive resources.
- Produces reproducible named exports which are easy to reconcile against source timestamps.
- Enables automation scenarios such as periodic backups, migrating historical telemetry, or feeding batch-processing pipelines.

Parameters and behavior (summary)

- StartDate / FinalDate: inclusive range for exported data; batches cover StartDate .. FinalDate in consecutive windows.
- KqlQuery: the KQL to run; the script injects a TimeGenerated between(...) filter per batch so you can keep a single query template.
- WorkspaceId: Log Analytics workspace ID to run queries against.
- ExportFolder / NamePrefix: base path and file name prefix for exported JSON files.
- SplitBy: determines how the output folders are organized (Year, Month, Day, Hour).
- minutesPerBatch: length of each export window in minutes (defaults to 60).

Usage example

- Single-run (PowerShell):
  - Provide a multi-line here-string for KqlQuery, set StartDate/FinalDate, WorkspaceId, and export path. Example in script header demonstrates a typical usage.

Output format

- Primary results are exported to JSON files named with Start/End timestamps and the configured name prefix.
- If query errors occur, a companion _ERRORS.json file is written to the same folder containing error details and the failed query result structure.
- Logging is written to a progress log file so you can monitor which batches completed or failed.

Operational best practices (applied from Azure recommendations)

- Credentials and secrets: Never store plaintext credentials in the repository or script parameters. Use Azure Managed Identity (system or user-assigned) or service principal credentials fetched from secure stores (Azure Key Vault) at runtime.
- Query design: Limit the query time range per batch. Keep result set sizes reasonable (use project/limit/where to reduce payload) to avoid excessive memory or API limits.
- Throttling and retries: Add retry/backoff logic for transient failures (network or service throttling) when integrating this script into automation. Consider adding Try–Catch with exponential backoff in orchestration layers.
- Permissions: Grant the minimum needed RBAC role to the identity running queries (e.g., Log Analytics Reader).
- Storage and retention: If keeping exported telemetry long-term, ensure storage lifecycle and retention policies meet compliance and cost goals. Use compressed formats or object storage for better efficiency if needed.
- Performance: Increase minutesPerBatch carefully — large windows produce larger payloads and increase memory/CPU usage. Conversely, very small windows increase API calls and overhead.
- Observability: Keep logging enabled (verbose option) and centralized. Emit timestamps and unique batch IDs to help reconcile exports with the source.

Security considerations

- Use Managed Identity for authentication where possible.
- Avoid writing secrets or credentials to logs or exported files.
- Restrict access to the ExportFolder to authorized users/processes.

Extending and contributing

- Consider adding:
  - Parallelization options for non-overlapping batches (with caution for workspace rate limits),
  - Output compression (gzip) for large exports,
  - Incremental resume logic to re-run only failed or missing batches,
  - Unit/integration tests or a dry‑run mode.
- Contributions and bug reports are welcome — please open issues or pull requests in the repository.

Requirements

- PowerShell with Az.OperationalInsights module installed.
- Permission to query the target Log Analytics workspace (Reader or equivalent).

## Contributing

Contributions are welcome! Please submit a pull request or open an issue for suggestions and improvements.

## License

This project is licensed under the MIT License.
