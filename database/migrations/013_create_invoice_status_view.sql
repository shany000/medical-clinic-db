
BEGIN;

CREATE OR REPLACE VIEW public.v_invoice_status AS
SELECT
    i.invoice_id,
    i.visit_id,
    i.invoice_number,
    i.issued_at,
    i.due_date,
    i.total_amount,
    COALESCE(p.paid_amount, 0::NUMERIC(12, 2)) AS paid_amount,
    GREATEST(
        i.total_amount - COALESCE(p.paid_amount, 0::NUMERIC),
        0::NUMERIC
    ) AS remaining_amount,
    CASE
        WHEN COALESCE(p.paid_amount, 0) >= i.total_amount
            THEN 'paid'
        WHEN CURRENT_DATE > i.due_date
            THEN 'overdue'
        WHEN COALESCE(p.paid_amount, 0) > 0
            THEN 'partially_paid'
        ELSE 'unpaid'
    END AS status
FROM public.invoices i
LEFT JOIN (
    SELECT
        invoice_id,
        SUM(amount) AS paid_amount
    FROM public.payments
    GROUP BY invoice_id
) p
    ON p.invoice_id = i.invoice_id;

COMMIT;
