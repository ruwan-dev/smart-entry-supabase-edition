# Reports Feature

## Overview
The `reports` feature is responsible for generating, viewing, and exporting various PDF reports based on the daily entries and customer data.

## Key Components
- **`ReportsScreen` (`reports_screen.dart`)**: The main interface for generating reports. It allows users to filter data by date range and select specific report types (e.g., Daily All Data, Customer Wise, Tea Leaves Only, Fertilizer Wise, Tea Packet Wise, Advances & Items). It uses `pdf` and `printing` packages to generate high-quality PDF documents based on the data retrieved from Supabase.
- **`MonthlyClosingWidget`**: A specialized widget within this feature to handle monthly summary logic and closings.
