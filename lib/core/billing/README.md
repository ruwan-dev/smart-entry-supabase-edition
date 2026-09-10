# Billing Core Module

## Overview
The `billing` module handles the financial calculations, monthly bill generation, and printing processes for the customers.

## Key Components
- **`MonthlyBillScreen` (`monthly_bill_screen.dart`)**: The UI for reviewing and managing monthly bills. It aggregates data from daily entries, applies monthly rates and global prices, and calculates the final payout or outstanding balance for each customer.
- **`BillPdfService` (`bill_pdf_service.dart`)**: A utility service responsible for formatting and exporting the calculated monthly bills into a professional PDF format.
- **`RawTextPrintService` (`raw_text_print_service.dart`)**: A specialized service to handle direct raw text printing, often used for thermal receipt printers to print quick transaction slips.
