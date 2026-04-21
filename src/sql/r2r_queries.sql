-- ============================================================
-- R2R Financial Close — SQL Extraction Scripts
-- KIIT University | SAP Business Data Cloud Project
-- Target: SAP HANA / Datasphere (via BDC pipeline)
-- ============================================================

-- ──────────────────────────────────────────
-- SCRIPT 1: Trial Balance Extraction
-- Source: GLT0 (GL Account Period Balances)
-- ──────────────────────────────────────────
SELECT
    g.BUKRS                          AS "Company Code",
    g.SAKNR                          AS "GL Account",
    s.TXT50                          AS "Account Description",
    k.KOART                          AS "Account Type",
    g.GJAHR                          AS "Fiscal Year",
    -- Cumulative balance through period 12
    (
        COALESCE(g.HSLVT, 0) +
        COALESCE(g.HSL01, 0) + COALESCE(g.HSL02, 0) + COALESCE(g.HSL03, 0) +
        COALESCE(g.HSL04, 0) + COALESCE(g.HSL05, 0) + COALESCE(g.HSL06, 0) +
        COALESCE(g.HSL07, 0) + COALESCE(g.HSL08, 0) + COALESCE(g.HSL09, 0) +
        COALESCE(g.HSL10, 0) + COALESCE(g.HSL11, 0) + COALESCE(g.HSL12, 0)
    )                                AS "Net Balance (INR)",
    CASE
        WHEN (COALESCE(g.HSLVT,0) + COALESCE(g.HSL01,0) + COALESCE(g.HSL02,0) +
              COALESCE(g.HSL03,0) + COALESCE(g.HSL04,0) + COALESCE(g.HSL05,0) +
              COALESCE(g.HSL06,0) + COALESCE(g.HSL07,0) + COALESCE(g.HSL08,0) +
              COALESCE(g.HSL09,0) + COALESCE(g.HSL10,0) + COALESCE(g.HSL11,0) +
              COALESCE(g.HSL12,0)) > 0
        THEN (COALESCE(g.HSLVT,0) + COALESCE(g.HSL01,0) + COALESCE(g.HSL02,0) +
              COALESCE(g.HSL03,0) + COALESCE(g.HSL04,0) + COALESCE(g.HSL05,0) +
              COALESCE(g.HSL06,0) + COALESCE(g.HSL07,0) + COALESCE(g.HSL08,0) +
              COALESCE(g.HSL09,0) + COALESCE(g.HSL10,0) + COALESCE(g.HSL11,0) +
              COALESCE(g.HSL12,0))
        ELSE 0
    END                              AS "Debit Balance",
    CASE
        WHEN (COALESCE(g.HSLVT,0) + COALESCE(g.HSL01,0) + COALESCE(g.HSL02,0) +
              COALESCE(g.HSL03,0) + COALESCE(g.HSL04,0) + COALESCE(g.HSL05,0) +
              COALESCE(g.HSL06,0) + COALESCE(g.HSL07,0) + COALESCE(g.HSL08,0) +
              COALESCE(g.HSL09,0) + COALESCE(g.HSL10,0) + COALESCE(g.HSL11,0) +
              COALESCE(g.HSL12,0)) < 0
        THEN ABS(COALESCE(g.HSLVT,0) + COALESCE(g.HSL01,0) + COALESCE(g.HSL02,0) +
                 COALESCE(g.HSL03,0) + COALESCE(g.HSL04,0) + COALESCE(g.HSL05,0) +
                 COALESCE(g.HSL06,0) + COALESCE(g.HSL07,0) + COALESCE(g.HSL08,0) +
                 COALESCE(g.HSL09,0) + COALESCE(g.HSL10,0) + COALESCE(g.HSL11,0) +
                 COALESCE(g.HSL12,0))
        ELSE 0
    END                              AS "Credit Balance",
    t.WAERS                          AS "Currency"

FROM GLT0 g
JOIN T001  t ON t.BUKRS = g.BUKRS
LEFT JOIN SKAT  s ON s.SAKNR = g.SAKNR
              AND s.SPRAS = 'E'
              AND s.KTOPL = t.KTOPL
LEFT JOIN SKA1  k ON k.SAKNR = g.SAKNR
              AND k.KTOPL = t.KTOPL

WHERE g.BUKRS = 'KAIL'            -- Company Code
  AND g.GJAHR = '2025'             -- Fiscal Year
  AND g.RRCTY = '0'               -- Record type (actual)

ORDER BY k.KOART, g.SAKNR;


-- ──────────────────────────────────────────
-- SCRIPT 2: Open Items — Accounts Receivable
-- Source: BSID (Open Customer Items)
-- ──────────────────────────────────────────
SELECT
    b.BUKRS   AS "Company Code",
    b.KUNNR   AS "Customer Number",
    k.NAME1   AS "Customer Name",
    b.BELNR   AS "Document Number",
    b.BUDAT   AS "Posting Date",
    b.FAEDT   AS "Due Date",
    b.WRBTR   AS "Amount (Doc Currency)",
    b.WAERS   AS "Doc Currency",
    b.DMBTR   AS "Amount (Local Currency)",
    DATEDIFF('DAY', b.FAEDT, CURRENT_DATE) AS "Days Overdue",
    CASE
        WHEN DATEDIFF('DAY', b.FAEDT, CURRENT_DATE) <= 0  THEN 'Not Due'
        WHEN DATEDIFF('DAY', b.FAEDT, CURRENT_DATE) <= 30 THEN '1-30 Days'
        WHEN DATEDIFF('DAY', b.FAEDT, CURRENT_DATE) <= 60 THEN '31-60 Days'
        WHEN DATEDIFF('DAY', b.FAEDT, CURRENT_DATE) <= 90 THEN '61-90 Days'
        ELSE 'Over 90 Days'
    END      AS "Aging Bucket"
FROM BSID b
JOIN KNA1 k ON k.KUNNR = b.KUNNR
WHERE b.BUKRS = 'KAIL'
ORDER BY b.FAEDT ASC;


-- ──────────────────────────────────────────
-- SCRIPT 3: GR/IR Reconciliation
-- Source: BSIM + RBKP
-- ──────────────────────────────────────────
SELECT
    m.EBELN   AS "Purchase Order",
    m.EBELP   AS "PO Line",
    m.MBLNR   AS "Material Document",
    m.BUDAT   AS "GR Posting Date",
    m.MENGE   AS "GR Quantity",
    m.WRBTR   AS "GR Amount (INR)",
    r.BELNR   AS "Invoice Document",
    r.BUDAT   AS "IR Posting Date",
    r.MENGE   AS "IR Quantity",
    r.WRBTR   AS "IR Amount (INR)",
    (m.WRBTR - COALESCE(r.WRBTR, 0)) AS "GR-IR Difference"
FROM MSEG m
LEFT JOIN (
    SELECT rs.EBELN, rs.EBELP, rh.BELNR, rh.BUDAT,
           rs.MENGE, rs.WRBTR
    FROM   RSEG rs
    JOIN   RBKP rh ON rh.BELNR = rs.BELNR AND rh.GJAHR = rs.GJAHR
    WHERE  rh.BUKRS = 'KAIL'
) r ON r.EBELN = m.EBELN AND r.EBELP = m.EBELP
WHERE m.BUKRS = 'KAIL'
  AND m.SHKZG = 'S'            -- Debit postings (GR)
  AND ABS(m.WRBTR - COALESCE(r.WRBTR, 0)) > 0.01
ORDER BY ABS(m.WRBTR - COALESCE(r.WRBTR, 0)) DESC;


-- ──────────────────────────────────────────
-- SCRIPT 4: Intercompany Balances Check
-- Source: BSEG
-- ──────────────────────────────────────────
SELECT
    b.BUKRS   AS "Company Code",
    b.VBUND   AS "Trading Partner",
    b.HKONT   AS "GL Account",
    SUM(CASE WHEN b.SHKZG = 'S' THEN b.DMBTR ELSE 0 END) AS "IC Debit",
    SUM(CASE WHEN b.SHKZG = 'H' THEN b.DMBTR ELSE 0 END) AS "IC Credit",
    SUM(CASE WHEN b.SHKZG = 'S' THEN b.DMBTR ELSE -b.DMBTR END) AS "IC Net Balance"
FROM BSEG b
JOIN BKPF h ON h.BUKRS = b.BUKRS AND h.BELNR = b.BELNR AND h.GJAHR = b.GJAHR
WHERE b.VBUND IS NOT NULL
  AND h.BUDAT BETWEEN '20250401' AND '20260331'
GROUP BY b.BUKRS, b.VBUND, b.HKONT
HAVING ABS(SUM(CASE WHEN b.SHKZG='S' THEN b.DMBTR ELSE -b.DMBTR END)) > 0
ORDER BY ABS(SUM(CASE WHEN b.SHKZG='S' THEN b.DMBTR ELSE -b.DMBTR END)) DESC;
