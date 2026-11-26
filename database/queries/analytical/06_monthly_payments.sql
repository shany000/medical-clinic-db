WITH params AS (
    SELECT
        DATE '2026-11-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_start,
        DATE '2027-01-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_end
)
SELECT
    DATE_TRUNC(
        'month',
        p.paid_at AT TIME ZONE 'Europe/Moscow'
    )::DATE AS payment_month,
    p.payment_method,
    COUNT(*) AS payments_count,
    COUNT(DISTINCT p.invoice_id) AS invoices_count,
    ROUND(SUM(p.amount), 2) AS total_received,
    ROUND(AVG(p.amount), 2) AS average_payment
FROM public.payments p
CROSS JOIN params prm
WHERE p.paid_at >= prm.period_start
  AND p.paid_at < prm.period_end
GROUP BY
    DATE_TRUNC('month', p.paid_at AT TIME ZONE 'Europe/Moscow')::DATE,
    p.payment_method
ORDER BY payment_month, p.payment_method;