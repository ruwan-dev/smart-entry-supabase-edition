# PDF Printing Constraints

**CRITICAL RULE: DO NOT CHANGE THE BILL PDF DIMENSIONS**

This document outlines the strict constraints for the monthly bill generation logic found in `lib/core/billing/bill_pdf_service.dart`. 

## 1. Fixed Paper Size (A5)
The printed bill is strictly formatted for A5 dot-matrix printing. 
- **Format:** `PdfPageFormat.a5` (Portrait)
- **Dimensions:** 148 mm (Width) × 210 mm (Height) / 5.83 in × 8.27 in.
- **Rule:** **NEVER** change the `pageFormat` from `a5`. The physical paper loaded into the factory dot-matrix printers relies on this exact dimension.

## 2. Vertical Space Constraint (No New Lines)
Because A5 has a strict height limit, adding new vertical text lines to the layout will cause the PDF to overflow onto a second blank page or cut off critical footer information.
- **Rule:** If new data needs to be displayed (such as a second Tea Rate or a second Leaf Weight), **DO NOT add new vertical rows**.
- **Solution:** Combine data horizontally. 
  - *Example (Rates):* Instead of a new line, combine as `Tea Rates: Rs.200/Rs.250 | Trans: Rs.15.00`.
  - *Example (Weights):* Instead of a new row for premium leaf weight, combine in the Qty column as `15.0+5.0`.

## 3. Font
- **Type:** `PdfGoogleFonts.courierPrimeRegular()`
- **Reason:** Courier is a monospaced font, which is standard and highly optimized for fast Dot-Matrix printing. Do not change to a variable-width font (like Roboto or Arial) as it will break the table alignment.
