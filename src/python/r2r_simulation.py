"""
R2R Financial Close - Simulation & Automation Script
KIIT University | SAP Business Data Cloud Project
Module: Record-to-Report (R2R) | Month-End / Year-End Financial Close

This script simulates the R2R financial close process:
  1. Generate trial balance data
  2. Run automated balance checks
  3. Produce reconciliation report
  4. Generate journal entries for closing

Software Required:
  - Python 3.10+
  - pandas, openpyxl, reportlab
  Install: pip install pandas openpyxl reportlab

GitHub: https://github.com/AnweshaB8/kiit-sap-r2r-project
"""

import pandas as pd
from datetime import datetime, date
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
)
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
import json
import os

# ─────────────────────────────────────────────
# 1. MASTER DATA — Fictitious Company Setup
# ─────────────────────────────────────────────

COMPANY = {
    "name": "Kalinga Industries Ltd.",
    "company_code": "KAIL",
    "country": "India",
    "currency": "INR",
    "fiscal_year": "April to March",
    "chart_of_accounts": "KAIL",
    "address": "Plot 5, Industrial Area, Bhubaneswar, Odisha - 751010"
}

# GL Account Master (Chart of Accounts)
GL_ACCOUNTS = [
    # Assets
    {"saknr": "100000", "txt50": "Cash and Cash Equivalents",    "koart": "S", "fsgrp": "Assets"},
    {"saknr": "100100", "txt50": "Accounts Receivable",           "koart": "S", "fsgrp": "Assets"},
    {"saknr": "100200", "txt50": "Inventory - Raw Materials",     "koart": "S", "fsgrp": "Assets"},
    {"saknr": "100300", "txt50": "Prepaid Expenses",              "koart": "S", "fsgrp": "Assets"},
    {"saknr": "110000", "txt50": "Plant & Machinery (Gross)",     "koart": "S", "fsgrp": "Assets"},
    {"saknr": "110100", "txt50": "Accumulated Depreciation",      "koart": "S", "fsgrp": "Assets"},
    # Liabilities
    {"saknr": "200000", "txt50": "Accounts Payable",              "koart": "S", "fsgrp": "Liabilities"},
    {"saknr": "200100", "txt50": "Short-Term Loans",              "koart": "S", "fsgrp": "Liabilities"},
    {"saknr": "200200", "txt50": "Accrued Expenses",              "koart": "S", "fsgrp": "Liabilities"},
    {"saknr": "200300", "txt50": "Tax Payable (GST)",             "koart": "S", "fsgrp": "Liabilities"},
    # Equity
    {"saknr": "300000", "txt50": "Share Capital",                 "koart": "S", "fsgrp": "Equity"},
    {"saknr": "300100", "txt50": "Retained Earnings",              "koart": "S", "fsgrp": "Equity"},
    # Revenue
    {"saknr": "400000", "txt50": "Revenue from Operations",       "koart": "S", "fsgrp": "Revenue"},
    {"saknr": "400100", "txt50": "Other Income",                  "koart": "S", "fsgrp": "Revenue"},
    # Expenses
    {"saknr": "500000", "txt50": "Cost of Goods Sold",            "koart": "S", "fsgrp": "Expenses"},
    {"saknr": "500100", "txt50": "Employee Salaries & Wages",     "koart": "S", "fsgrp": "Expenses"},
    {"saknr": "500200", "txt50": "Rent & Utilities",              "koart": "S", "fsgrp": "Expenses"},
    {"saknr": "500300", "txt50": "Depreciation Expense",          "koart": "S", "fsgrp": "Expenses"},
    {"saknr": "500400", "txt50": "Marketing & Advertising",       "koart": "S", "fsgrp": "Expenses"},
    {"saknr": "500500", "txt50": "Finance Costs (Interest)",      "koart": "S", "fsgrp": "Expenses"},
]

# Trial Balance Data (March 2025 — Year End)
TRIAL_BALANCE_DATA = [
    {"saknr": "100000", "debit": 4500000,  "credit": 0,        "currency": "INR"},
    {"saknr": "100100", "debit": 8750000,  "credit": 0,        "currency": "INR"},
    {"saknr": "100200", "debit": 3200000,  "credit": 0,        "currency": "INR"},
    {"saknr": "100300", "debit": 250000,   "credit": 0,        "currency": "INR"},
    {"saknr": "110000", "debit": 15000000, "credit": 0,        "currency": "INR"},
    {"saknr": "110100", "debit": 0,        "credit": 4500000,  "currency": "INR"},
    {"saknr": "200000", "debit": 0,        "credit": 5200000,  "currency": "INR"},
    {"saknr": "200100", "debit": 0,        "credit": 3000000,  "currency": "INR"},
    {"saknr": "200200", "debit": 0,        "credit": 750000,   "currency": "INR"},
    {"saknr": "200300", "debit": 0,        "credit": 450000,   "currency": "INR"},
    {"saknr": "300000", "debit": 0,        "credit": 10000000, "currency": "INR"},
    {"saknr": "300100", "debit": 0,        "credit": 3800000,  "currency": "INR"},
    {"saknr": "400000", "debit": 0,        "credit": 22000000, "currency": "INR"},
    {"saknr": "400100", "debit": 0,        "credit": 500000,   "currency": "INR"},
    {"saknr": "500000", "debit": 13200000, "credit": 0,        "currency": "INR"},
    {"saknr": "500100", "debit": 2800000,  "credit": 0,        "currency": "INR"},
    {"saknr": "500200", "debit": 800000,   "credit": 0,        "currency": "INR"},
    {"saknr": "500300", "debit": 900000,   "credit": 0,        "currency": "INR"},
    {"saknr": "500400", "debit": 350000,   "credit": 0,        "currency": "INR"},
    {"saknr": "500500", "debit": 450000,   "credit": 0,        "currency": "INR"},
]

# ─────────────────────────────────────────────
# 2. CLOSING JOURNAL ENTRIES
# ─────────────────────────────────────────────

CLOSING_ENTRIES = [
    {
        "step": 1,
        "description": "Depreciation Accrual — FY 2024-25",
        "date": "31-Mar-2025",
        "postings": [
            {"account": "500300", "name": "Depreciation Expense",  "dr": 900000,  "cr": 0},
            {"account": "110100", "name": "Accumulated Depreciation","dr": 0,     "cr": 900000},
        ]
    },
    {
        "step": 2,
        "description": "Accrued Salaries — March 2025",
        "date": "31-Mar-2025",
        "postings": [
            {"account": "500100", "name": "Salaries & Wages",      "dr": 250000,  "cr": 0},
            {"account": "200200", "name": "Accrued Expenses",       "dr": 0,      "cr": 250000},
        ]
    },
    {
        "step": 3,
        "description": "Revenue Recognition — Deferred Income",
        "date": "31-Mar-2025",
        "postings": [
            {"account": "400000", "name": "Revenue from Operations","dr": 0,      "cr": 500000},
            {"account": "200200", "name": "Accrued Expenses",       "dr": 500000, "cr": 0},
        ]
    },
    {
        "step": 4,
        "description": "Closing P&L to Retained Earnings",
        "date": "31-Mar-2025",
        "postings": [
            {"account": "400000", "name": "Revenue from Operations","dr": 22000000,"cr": 0},
            {"account": "400100", "name": "Other Income",           "dr": 500000,  "cr": 0},
            {"account": "500000", "name": "COGS",                  "dr": 0,       "cr": 13200000},
            {"account": "500100", "name": "Salaries",              "dr": 0,       "cr": 2800000},
            {"account": "500200", "name": "Rent & Utilities",      "dr": 0,       "cr": 800000},
            {"account": "500300", "name": "Depreciation",          "dr": 0,       "cr": 900000},
            {"account": "500400", "name": "Marketing",             "dr": 0,       "cr": 350000},
            {"account": "500500", "name": "Finance Costs",         "dr": 0,       "cr": 450000},
            {"account": "300100", "name": "Retained Earnings",     "dr": 0,       "cr": 4000000},
        ]
    },
]

# ─────────────────────────────────────────────
# 3. TRIAL BALANCE COMPUTATION
# ─────────────────────────────────────────────

def build_trial_balance():
    """Merge GL master with trial balance data."""
    gl_df  = pd.DataFrame(GL_ACCOUNTS)
    tb_df  = pd.DataFrame(TRIAL_BALANCE_DATA)
    merged = gl_df.merge(tb_df, on="saknr", how="left").fillna(0)
    merged["net_balance"] = merged["debit"] - merged["credit"]
    return merged

def check_balance(df):
    """Check that total debits equal total credits."""
    total_dr = df["debit"].sum()
    total_cr = df["credit"].sum()
    balanced = abs(total_dr - total_cr) < 0.01
    return total_dr, total_cr, balanced

# ─────────────────────────────────────────────
# 4. PDF REPORT GENERATION
# ─────────────────────────────────────────────

def fmt_inr(value):
    """Format number as Indian Rupee string."""
    if value == 0:
        return "-"
    return f"₹ {value:,.0f}"

def generate_pdf_report(output_path="r2r_financial_close_report.pdf"):
    df = build_trial_balance()
    total_dr, total_cr, balanced = check_balance(df)

    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        rightMargin=0.75*inch, leftMargin=0.75*inch,
        topMargin=0.75*inch, bottomMargin=0.75*inch
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("Title", parent=styles["Title"],
                                 fontSize=16, textColor=colors.HexColor("#1B3A6B"),
                                 spaceAfter=6, alignment=TA_CENTER)
    h1_style = ParagraphStyle("H1", parent=styles["Heading1"],
                               fontSize=13, textColor=colors.HexColor("#1B3A6B"),
                               spaceAfter=4, spaceBefore=12)
    h2_style = ParagraphStyle("H2", parent=styles["Heading2"],
                               fontSize=11, textColor=colors.HexColor("#2E75B6"),
                               spaceAfter=4, spaceBefore=8)
    body = styles["Normal"]
    body.fontSize = 9

    story = []

    # ── Cover Header ──
    story.append(Paragraph("KIIT University — SAP Business Data Cloud", title_style))
    story.append(Paragraph("SAP ERP Project Report", title_style))
    story.append(Spacer(1, 0.1*inch))
    story.append(Paragraph("Record-to-Report (R2R) — Month-End / Year-End Financial Close", h1_style))
    story.append(Spacer(1, 0.05*inch))

    # Company Info Table
    company_data = [
        ["Company", COMPANY["name"], "Company Code", COMPANY["company_code"]],
        ["Country", COMPANY["country"], "Currency", COMPANY["currency"]],
        ["Fiscal Year", COMPANY["fiscal_year"], "Chart of Accounts", COMPANY["chart_of_accounts"]],
        ["Report Date", date.today().strftime("%d-%b-%Y"), "Reporting Period", "FY 2024-25 (Mar)"],
    ]
    co_table = Table(company_data, colWidths=[1.4*inch, 2.2*inch, 1.6*inch, 1.9*inch])
    co_table.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (0,-1), colors.HexColor("#E8EEF6")),
        ("BACKGROUND", (2,0), (2,-1), colors.HexColor("#E8EEF6")),
        ("FONTNAME", (0,0), (-1,-1), "Helvetica"),
        ("FONTSIZE", (0,0), (-1,-1), 8),
        ("GRID", (0,0), (-1,-1), 0.5, colors.grey),
        ("PADDING", (0,0), (-1,-1), 5),
    ]))
    story.append(co_table)
    story.append(Spacer(1, 0.2*inch))

    # ── Section 1: Trial Balance ──
    story.append(Paragraph("1. Pre-Close Trial Balance — FY 2024-25", h1_style))

    tb_headers = ["GL Account", "Description", "Group", "Debit (INR)", "Credit (INR)", "Net Balance"]
    tb_rows = [tb_headers]
    for _, row in df.iterrows():
        tb_rows.append([
            row["saknr"],
            row["txt50"],
            row["fsgrp"],
            fmt_inr(row["debit"]),
            fmt_inr(row["credit"]),
            fmt_inr(row["net_balance"]),
        ])
    # Totals row
    tb_rows.append([
        "TOTAL", "", "",
        fmt_inr(total_dr),
        fmt_inr(total_cr),
        fmt_inr(total_dr - total_cr)
    ])

    tb_table = Table(tb_rows, colWidths=[0.85*inch, 2.1*inch, 0.9*inch, 1.1*inch, 1.1*inch, 1.1*inch])
    tb_table.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,0), colors.HexColor("#1B3A6B")),
        ("TEXTCOLOR", (0,0), (-1,0), colors.white),
        ("FONTNAME", (0,0), (-1,0), "Helvetica-Bold"),
        ("FONTSIZE", (0,0), (-1,-1), 7.5),
        ("GRID", (0,0), (-1,-1), 0.4, colors.HexColor("#CCCCCC")),
        ("ROWBACKGROUNDS", (0,1), (-1,-2), [colors.white, colors.HexColor("#F2F5FA")]),
        ("BACKGROUND", (0,-1), (-1,-1), colors.HexColor("#D4E3F5")),
        ("FONTNAME", (0,-1), (-1,-1), "Helvetica-Bold"),
        ("ALIGN", (3,0), (-1,-1), "RIGHT"),
        ("PADDING", (0,0), (-1,-1), 4),
        ("TOPPADDING", (0,0), (-1,0), 6),
    ]))
    story.append(tb_table)

    bal_text = "✅ Trial Balance is BALANCED" if balanced else "❌ Trial Balance is OUT OF BALANCE"
    bal_color = "#1A7A1A" if balanced else "#CC0000"
    story.append(Spacer(1, 0.1*inch))
    story.append(Paragraph(f'<font color="{bal_color}"><b>{bal_text}</b></font>', body))
    story.append(PageBreak())

    # ── Section 2: Month-End Closing Steps ──
    story.append(Paragraph("2. Month-End / Year-End Closing Checklist", h1_style))

    steps = [
        ("Step 1", "Post Accruals & Deferrals", "Completed",
         "Post accrued expenses (salaries, rent) and deferred revenue entries via FB50."),
        ("Step 2", "Run Depreciation (AFAB)", "Completed",
         "Execute asset depreciation run for all asset classes in Company Code KAIL."),
        ("Step 3", "Foreign Currency Revaluation (FAGL_FC_VAL)", "Completed",
         "Revalue open items in foreign currency at period-end exchange rates."),
        ("Step 4", "GR/IR Account Clearing (MR11)", "Completed",
         "Clear Goods Receipt / Invoice Receipt account mismatches."),
        ("Step 5", "Intercompany Reconciliation", "Completed",
         "Reconcile all intercompany balances; ensure zero net position."),
        ("Step 6", "Run Balance Carry Forward (F.16)", "Completed",
         "Carry forward P&L balances to retained earnings for new fiscal year."),
        ("Step 7", "Close Posting Period (OB52)", "Completed",
         "Lock current period for postings; open new period for next cycle."),
        ("Step 8", "Generate Financial Statements (F.01)", "Completed",
         "Run Balance Sheet and P&L statement; distribute to management."),
    ]

    step_headers = ["Step", "Activity", "Status", "Details"]
    step_rows = [step_headers] + [list(s) for s in steps]
    step_table = Table(step_rows, colWidths=[0.6*inch, 1.8*inch, 0.9*inch, 3.8*inch])
    step_table.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,0), colors.HexColor("#2E75B6")),
        ("TEXTCOLOR", (0,0), (-1,0), colors.white),
        ("FONTNAME", (0,0), (-1,0), "Helvetica-Bold"),
        ("FONTSIZE", (0,0), (-1,-1), 7.5),
        ("GRID", (0,0), (-1,-1), 0.4, colors.HexColor("#CCCCCC")),
        ("ROWBACKGROUNDS", (0,1), (-1,-1), [colors.white, colors.HexColor("#F2F5FA")]),
        ("VALIGN", (0,0), (-1,-1), "TOP"),
        ("PADDING", (0,0), (-1,-1), 5),
    ]))
    story.append(step_table)
    story.append(PageBreak())

    # ── Section 3: Closing Journal Entries ──
    story.append(Paragraph("3. Closing Journal Entries", h1_style))

    for entry in CLOSING_ENTRIES:
        story.append(Paragraph(f"Step {entry['step']}: {entry['description']} — {entry['date']}", h2_style))
        je_headers = ["GL Account", "Account Name", "Debit (INR)", "Credit (INR)"]
        je_rows = [je_headers]
        total_d = 0
        total_c = 0
        for p in entry["postings"]:
            je_rows.append([p["account"], p["name"], fmt_inr(p["dr"]), fmt_inr(p["cr"])])
            total_d += p["dr"]
            total_c += p["cr"]
        je_rows.append(["", "TOTAL", fmt_inr(total_d), fmt_inr(total_c)])

        je_table = Table(je_rows, colWidths=[1*inch, 2.6*inch, 1.5*inch, 1.5*inch])
        je_table.setStyle(TableStyle([
            ("BACKGROUND", (0,0), (-1,0), colors.HexColor("#4472C4")),
            ("TEXTCOLOR", (0,0), (-1,0), colors.white),
            ("FONTNAME", (0,0), (-1,0), "Helvetica-Bold"),
            ("FONTSIZE", (0,0), (-1,-1), 8),
            ("GRID", (0,0), (-1,-1), 0.4, colors.lightgrey),
            ("ROWBACKGROUNDS", (0,1), (-1,-2), [colors.white, colors.HexColor("#EDF3FB")]),
            ("BACKGROUND", (0,-1), (-1,-1), colors.HexColor("#D4E3F5")),
            ("FONTNAME", (0,-1), (-1,-1), "Helvetica-Bold"),
            ("ALIGN", (2,0), (3,-1), "RIGHT"),
            ("PADDING", (0,0), (-1,-1), 4),
        ]))
        story.append(je_table)
        story.append(Spacer(1, 0.1*inch))

    story.append(PageBreak())

    # ── Section 4: SAP BDC Integration Note ──
    story.append(Paragraph("4. SAP Business Data Cloud Integration", h1_style))
    bdc_points = [
        "SAP BDC connects SAP S/4HANA financial data to SAP Datasphere for unified reporting.",
        "R2R process data (journal entries, trial balance, financial statements) flows via BDC pipelines.",
        "Real-time GL balance monitoring is enabled through SAP Analytics Cloud (SAC) dashboards.",
        "Automated variance alerts trigger when account balances deviate beyond defined thresholds.",
        "Period-end packages automate the extraction of FI posting data into BDC for consolidation.",
        "Data quality checks run at each stage: completeness, accuracy, and reconciliation validations.",
    ]
    for pt in bdc_points:
        story.append(Paragraph(f"• {pt}", body))
        story.append(Spacer(1, 0.04*inch))

    story.append(Spacer(1, 0.2*inch))
    story.append(Paragraph("5. Tools & Software Used", h1_style))
    tools = [
        ["Tool / Software", "Purpose", "Version / Notes"],
        ["SAP S/4HANA", "Core ERP — FI Module for GL, AP, AR", "S/4HANA 2023"],
        ["SAP Business Data Cloud (BDC)", "Data integration & unified analytics", "BDC 2024"],
        ["SAP Datasphere", "Central data warehouse / semantic layer", "Cloud Edition"],
        ["SAP Analytics Cloud (SAC)", "Financial dashboards & variance analysis", "Cloud Edition"],
        ["SAP ABAP Workbench / SE80", "Custom report development (ZR2R_TRIAL_BALANCE)", "NW 7.5+"],
        ["SAP Fiori", "Modern UX for period-end apps", "Fiori 3.0"],
        ["Python 3.11 + pandas", "Data simulation, automation scripts", "pandas 2.x"],
        ["Git + GitHub", "Version control for code and reports", "git 2.4+"],
        ["Visual Studio Code", "IDE for Python, ABAP, SQL development", "Latest"],
    ]
    tool_table = Table(tools, colWidths=[2*inch, 3*inch, 2.1*inch])
    tool_table.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,0), colors.HexColor("#1B3A6B")),
        ("TEXTCOLOR", (0,0), (-1,0), colors.white),
        ("FONTNAME", (0,0), (-1,0), "Helvetica-Bold"),
        ("FONTSIZE", (0,0), (-1,-1), 8),
        ("GRID", (0,0), (-1,-1), 0.4, colors.lightgrey),
        ("ROWBACKGROUNDS", (0,1), (-1,-1), [colors.white, colors.HexColor("#F2F5FA")]),
        ("PADDING", (0,0), (-1,-1), 5),
    ]))
    story.append(tool_table)

    doc.build(story)
    print(f"[✅] PDF report generated: {output_path}")
    return output_path

# ─────────────────────────────────────────────
# 5. EXCEL EXPORT
# ─────────────────────────────────────────────

def export_to_excel(output_path="r2r_trial_balance.xlsx"):
    df = build_trial_balance()
    total_dr, total_cr, balanced = check_balance(df)

    with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
        # Sheet 1 — Trial Balance
        df_export = df[["saknr","txt50","fsgrp","debit","credit","net_balance","currency"]].copy()
        df_export.columns = ["GL Account","Description","Group","Debit","Credit","Net Balance","Currency"]
        df_export.to_excel(writer, index=False, sheet_name="Trial Balance")

        # Sheet 2 — Closing Entries
        rows = []
        for entry in CLOSING_ENTRIES:
            for p in entry["postings"]:
                rows.append({
                    "Step": entry["step"],
                    "Description": entry["description"],
                    "Date": entry["date"],
                    "GL Account": p["account"],
                    "Account Name": p["name"],
                    "Debit": p["dr"],
                    "Credit": p["cr"],
                })
        pd.DataFrame(rows).to_excel(writer, index=False, sheet_name="Closing Entries")

        # Sheet 3 — Summary
        summary = pd.DataFrame([
            {"Item": "Total Debits", "Amount": total_dr},
            {"Item": "Total Credits", "Amount": total_cr},
            {"Item": "Difference", "Amount": total_dr - total_cr},
            {"Item": "Balanced?", "Amount": "YES" if balanced else "NO"},
        ])
        summary.to_excel(writer, index=False, sheet_name="Summary")

    print(f"[✅] Excel exported: {output_path}")
    return output_path

# ─────────────────────────────────────────────
# 6. MAIN
# ─────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("  KIIT SAP BDC Project — R2R Financial Close Simulation")
    print("=" * 60)

    df = build_trial_balance()
    total_dr, total_cr, balanced = check_balance(df)

    print(f"\n  Company     : {COMPANY['name']} ({COMPANY['company_code']})")
    print(f"  Period      : FY 2024-25 | March Year-End")
    print(f"  Total Debit : ₹ {total_dr:,.0f}")
    print(f"  Total Credit: ₹ {total_cr:,.0f}")
    print(f"  Balanced    : {'✅ YES' if balanced else '❌ NO'}")
    print()

    os.makedirs("output", exist_ok=True)
    generate_pdf_report("output/r2r_financial_close_report.pdf")
    export_to_excel("output/r2r_trial_balance.xlsx")

    print("\n  All outputs saved to ./output/")
    print("=" * 60)
