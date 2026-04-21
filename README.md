# 📊 KIIT SAP BDC Project — Record-to-Report (R2R) Financial Close

> **KIIT University | SAP Business Data Cloud Course**
> **Topic: Record-to-Report (R2R) — Month-End / Year-End Financial Close**
> **Fictitious Company: Kalinga Industries Ltd. (Company Code: KAIL)**

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Fictitious Company Setup](#fictitious-company-setup)
3. [R2R Process Flow](#r2r-process-flow)
4. [SAP Customization Steps](#sap-customization-steps)
5. [Month-End Closing Checklist](#month-end-closing-checklist)
6. [Year-End Closing Steps](#year-end-closing-steps)
7. [SAP BDC Integration](#sap-business-data-cloud-integration)
8. [Repository Structure](#repository-structure)
9. [How to Run the Code](#how-to-run-the-code)
10. [Software & Tools](#software--tools)

---

## 🎯 Project Overview

The **Record-to-Report (R2R)** process covers the complete financial close lifecycle in SAP — from recording business transactions to generating statutory financial statements. This project simulates the entire R2R cycle for a fictitious Indian manufacturing company using:

- **SAP S/4HANA FI** (Financial Accounting) — GL, AP, AR, Asset Accounting
- **SAP Business Data Cloud (BDC)** — Data pipeline for financial reporting
- **SAP Datasphere** — Unified semantic data layer
- **SAP Analytics Cloud (SAC)** — Dashboard and variance reporting
- **Custom ABAP Report** — Trial Balance ALV (`ZR2R_TRIAL_BALANCE`)
- **Python automation** — Period-end simulation and PDF report generation

---

## 🏢 Fictitious Company Setup

### Company: Kalinga Industries Ltd.

| Attribute | Value |
|-----------|-------|
| Company Name | Kalinga Industries Ltd. |
| Company Code | `KAIL` |
| Country | India |
| Currency | INR (Indian Rupee) |
| Fiscal Year Variant | `V3` (April–March) |
| Chart of Accounts | `KAIL` |
| Posting Period Variant | `KAIL` |
| Industry | Manufacturing (Chemicals) |
| Location | Bhubaneswar, Odisha |

### Organizational Structure

```
Kalinga Industries Ltd. (KAIL)
├── Company Code: KAIL (Bhubaneswar - HQ)
├── Business Area: BA01 - Manufacturing
│                  BA02 - Trading
├── Controlling Area: KAIL
│   ├── Cost Center: CC_PROD (Production)
│   ├── Cost Center: CC_ADMIN (Administration)
│   └── Cost Center: CC_SALE (Sales)
└── Plant: KL01 (Bhubaneswar Plant)
    └── Storage Location: SL01
```

### Chart of Accounts (Key GL Accounts)

| GL Account | Description | Type |
|-----------|-------------|------|
| 100000 | Cash & Cash Equivalents | Asset |
| 100100 | Accounts Receivable | Asset |
| 100200 | Inventory - Raw Materials | Asset |
| 110000 | Plant & Machinery (Gross) | Asset |
| 110100 | Accumulated Depreciation | Asset (Credit) |
| 200000 | Accounts Payable | Liability |
| 200200 | Accrued Expenses | Liability |
| 300000 | Share Capital | Equity |
| 300100 | Retained Earnings | Equity |
| 400000 | Revenue from Operations | Revenue |
| 500000 | Cost of Goods Sold | Expense |
| 500100 | Salaries & Wages | Expense |
| 500300 | Depreciation Expense | Expense |

---

## 🔄 R2R Process Flow

```
Business Transaction
       │
       ▼
┌─────────────────────┐
│  Journal Entry Post │  ← FB50 / FB60 / FB70 / MIRO
│  (SAP FI Module)   │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Sub-Ledger Update  │  ← AR (BSID), AP (BSIK), Asset (ANLC)
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  GL Account Update  │  ← GLT0, FAGLFLEXA
└────────┬────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  PERIOD-END CLOSING ACTIVITIES  │
│  ─────────────────────────────  │
│  1. Accruals & Deferrals        │
│  2. Depreciation Run (AFAB)     │
│  3. FX Revaluation              │
│  4. GR/IR Clearing (MR11)       │
│  5. Intercompany Reconciliation │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────┐
│  Trial Balance      │  ← F.08 / ZR2R_TRIAL_BALANCE (Custom)
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Financial Close    │  ← OB52 (Lock Period)
│  Period Lock        │  ← F.16 (Balance Carry Forward)
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Financial Reports  │  ← F.01 (Balance Sheet + P&L)
│  & Disclosures      │  ← S_ALR_87012284 (GL Line Items)
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  SAP BDC Pipeline   │  ← Data flows to Datasphere
│  → SAC Dashboard    │  ← Management reporting
└─────────────────────┘
```

---

## ⚙️ SAP Customization Steps

### Step 1: Enterprise Structure Setup

**T-Code: SPRO → Enterprise Structure → Definition → Financial Accounting**

1. **Create Company Code** (`OX02`)
   - Company Code: `KAIL`
   - Company Name: Kalinga Industries Ltd.
   - City: Bhubaneswar | Country: IN | Currency: INR | Language: EN

2. **Assign Company Code to Company** (`OX16`)

3. **Create Fiscal Year Variant** (`OB29`)
   - Variant: `V3` | April–March (Indian fiscal year)
   - 12 normal periods + 4 special periods

4. **Assign FY Variant to Company Code** (`OB37`)
   - Company Code: `KAIL` | FY Variant: `V3`

5. **Create Posting Period Variant** (`OBBO`)
   - Variant: `KAIL`

6. **Open and Close Posting Periods** (`OB52`)

### Step 2: Chart of Accounts

7. **Create Chart of Accounts** (`OB13`)
   - CoA: `KAIL` | Description: Kalinga CoA | Maintenance Language: EN

8. **Assign CoA to Company Code** (`OB62`)

9. **Create GL Accounts in CoA** (`FS00`)
   - Create each account from the master list above
   - Set account group, P&L/Balance Sheet indicator

### Step 3: Document Types & Number Ranges

10. **Define Document Types** (`OBA7`)
    - SA: GL Document | KR: Vendor Invoice | DR: Customer Invoice | AA: Asset Posting

11. **Define Number Ranges** (`FBN1`)
    - Company Code: `KAIL` | Year: 2025 | Range: 0100000000–0199999999

### Step 4: Tolerance Groups

12. **Define Tolerance Groups** (`OBA4`)
    - Upper limit for payment differences, open item clearing tolerances

### Step 5: Tax Configuration (India-specific)

13. **Define Tax Codes** (`FTXP`)
    - V0: Input Tax 0% | V5: Input GST 5% | V1: Input GST 18%
    - A0: Output Tax 0% | A5: Output GST 5% | A1: Output GST 18%

### Step 6: Asset Accounting

14. **Copy Reference Chart of Depreciation** (`EC08`)
    - Reference: `0IN` (India) → Target: `KAIL`

15. **Assign Company Code to Chart of Depreciation** (`OAOB`)

16. **Define Depreciation Areas** (`OADB`)
    - Area 01: Book Depreciation | Area 15: Tax Depreciation

17. **Define Depreciation Keys** (`AFAMA`)
    - `LINR` — Straight Line | `DEGR` — Declining Balance

---

## 📅 Month-End Closing Checklist

| # | Activity | T-Code | Owner | Status |
|---|----------|--------|-------|--------|
| 1 | Post all accruals & deferrals | FB50 | Accountant | ✅ |
| 2 | Run depreciation | AFAB | Asset Accountant | ✅ |
| 3 | FX revaluation | FAGL_FC_VAL | Finance | ✅ |
| 4 | GR/IR clearing | MR11 | AP Team | ✅ |
| 5 | Intercompany reconciliation | FBICR1 | Finance | ✅ |
| 6 | Run trial balance | F.08 | Controller | ✅ |
| 7 | Custom trial balance (ALV) | ZR2R_TRIAL_BALANCE | Controller | ✅ |
| 8 | Lock posting period | OB52 | Finance Manager | ✅ |
| 9 | Run financial statements | F.01 | CFO | ✅ |
| 10 | BDC pipeline extraction | SAP BDC | IT/BDC Admin | ✅ |

---

## 📆 Year-End Closing Steps

### Step 1: Pre-Close Activities
- Complete all month-end activities for Period 12
- Resolve all open items in AR / AP
- Ensure all asset retirements and acquisitions are posted

### Step 2: Carry Forward Open Items
```
T-Code: F.07 — Carry Forward Vendor/Customer Balances
T-Code: F.16 — Carry Forward GL Balances
```

### Step 3: Close Fiscal Year
```
T-Code: OB52 — Close all periods for FY 2025
         Open Period 1 for FY 2026
```

### Step 4: Run Year-End Reports
```
T-Code: F.01  — Financial Statements (Balance Sheet + P&L)
T-Code: S_ALR_87012284 — GL Account Balances
T-Code: S_ALR_87012172 — Customer Balance Report
T-Code: S_ALR_87012082 — Vendor Balance Report
```

### Step 5: BDC Year-End Package
- Trigger BDC replication job for full FY dataset
- Load into SAP Datasphere for consolidation
- Publish SAC dashboards for Board reporting

---

## ☁️ SAP Business Data Cloud Integration

```
SAP S/4HANA (KAIL)
      │  CDS Views / BDC Replication
      ▼
SAP Business Data Cloud
      │  Data Pipeline
      ▼
SAP Datasphere (Semantic Layer)
      │  Business Entity / Analytic Model
      ▼
SAP Analytics Cloud (SAC)
      │
      ├── Trial Balance Dashboard
      ├── P&L Variance Report
      ├── Cash Flow Monitor
      └── Period-End Status Tracker
```

**Key BDC Artifacts:**
- `C_GLACCTBAL_Q0001` — GL Account Balance CDS View
- `C_TRIALBCQ0001` — Trial Balance Query
- `I_GLACCOUNT` — GL Account Master Interface View

---

## 📁 Repository Structure

```
kiit-sap-r2r-project/
│
├── README.md                          ← This file
│
├── docs/
│   ├── R2R_Project_Report.docx        ← Word project report
│   ├── R2R_Project_Report.pdf         ← PDF version
│   └── r2r_financial_close_report.pdf ← Generated data report
│
├── src/
│   ├── abap/
│   │   └── ZR2R_TRIAL_BALANCE.abap    ← Custom ALV Trial Balance report
│   │
│   ├── python/
│   │   └── r2r_simulation.py          ← R2R close simulation + PDF generator
│   │
│   └── sql/
│       └── r2r_queries.sql            ← SAP HANA / Datasphere SQL scripts
│
├── config/
│   └── company_config.json            ← Company master data config
│
├── data/
│   └── sample/
│       └── trial_balance_sample.csv   ← Sample trial balance data
│
├── output/                            ← Generated reports (git-ignored)
│   ├── r2r_financial_close_report.pdf
│   └── r2r_trial_balance.xlsx
│
└── .gitignore
```

---

## 🚀 How to Run the Code

### Prerequisites

```bash
# Install Python dependencies
pip install pandas openpyxl reportlab

# Clone the repository
git clone https://github.com/YOUR_USERNAME/kiit-sap-r2r-project.git
cd kiit-sap-r2r-project
```

### Run the Python Simulation

```bash
cd src/python
python r2r_simulation.py
```

This generates:
- `output/r2r_financial_close_report.pdf` — Full financial close PDF report
- `output/r2r_trial_balance.xlsx` — Excel trial balance workbook

### ABAP — Deploy in SAP System

1. Open **SE38** (ABAP Editor) or **SE80** (Object Navigator)
2. Create new program `ZR2R_TRIAL_BALANCE`
3. Copy contents of `src/abap/ZR2R_TRIAL_BALANCE.abap`
4. Activate the program (`Ctrl+F3`)
5. Execute (`F8`) — Enter Company Code `KAIL`, FY `2025`, Period `12`

### SQL — Execute in SAP HANA Studio / DBeaver

1. Open `src/sql/r2r_queries.sql`
2. Connect to your SAP HANA instance
3. Run each script individually (see comments for purpose)

---

## 🛠️ Software & Tools

| Tool | Purpose | Download |
|------|---------|---------|
| SAP S/4HANA (Trial) | Core ERP | [SAP BTP Trial](https://www.sap.com/products/erp/s4hana.html) |
| SAP BDC | Data Cloud Integration | Part of SAP BTP |
| SAP Datasphere | Semantic Data Layer | [SAP Datasphere](https://www.sap.com/products/technology-platform/datasphere.html) |
| SAP Analytics Cloud | Dashboards | [SAC Trial](https://www.sap.com/products/technology-platform/cloud-analytics.html) |
| Python 3.11+ | Simulation scripts | [python.org](https://www.python.org) |
| Visual Studio Code | Code editor | [code.visualstudio.com](https://code.visualstudio.com) |
| Git | Version control | [git-scm.com](https://git-scm.com) |
| GitHub Desktop | GUI for Git | [desktop.github.com](https://desktop.github.com) |

---

## 👤 Author

**Student Name:** [Your Name]
**Roll Number:** [Your Roll No]
**Course:** SAP Business Data Cloud
**University:** KIIT University, Bhubaneswar
**Year:** 2025

---

## 📄 License

This project is for academic purposes — KIIT University SAP BDC Project Submission 2025.
