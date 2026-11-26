WITH params AS (
    SELECT
        DATE '2026-11-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_start,
        DATE '2027-01-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_end
)
SELECT
    CASE
        WHEN GROUPING(v.status) = 1 THEN 'TOTAL'
        ELSE v.status
    END AS invoice_status,
    COUNT(*) AS invoices_count,
    ROUND(SUM(v.total_amount), 2) AS billed_amount,
    ROUND(SUM(v.paid_amount), 2) AS paid_amount,
    ROUND(SUM(v.remaining_amount), 2) AS remaining_amount
FROM public.v_invoice_status v
CROSS JOIN params prm
WHERE v.issued_at >= prm.period_start
  AND v.issued_at < prm.period_end
GROUP BY GROUPING SETS (
    (v.status),
    ()
)
ORDER BY GROUPING(v.status), invoice_status;