Сводка для директора

SELECT
    DATE_TRUNC('month', p.payment_date)::date AS report_month,
    rc.category_code AS room_category,
    r.room_number,
    b.checkin_date,
    b.checkout_date,
    (b.checkout_date - b.checkin_date) AS nights,
    COUNT(DISTINCT bg.guest_id) AS guests_count,
    COUNT(DISTINCT bp.pet_id) AS pets_count,
    b.total_cost AS booking_gross_amount,
    COALESCE(b.discount_applied, 0) AS discount_amount,
    (b.total_cost - COALESCE(b.discount_applied, 0)) AS net_revenue,
    p.amount AS payment_amount,
    p.payment_method,
    (promo_details->>'promo_code')::VARCHAR AS promo_code,
    CASE
        WHEN (promo_details->>'promo_code') IS NOT NULL THEN 'Да'
        ELSE 'Нет'
    END AS used_promo,
    rs.status_code AS current_room_status
FROM payments p
JOIN bookings b ON p.booking_id = b.id
JOIN rooms r ON b.room_id = r.id
JOIN room_categories rc ON r.category_id = rc.id
LEFT JOIN room_current_state rcs ON r.id = rcs.room_id
LEFT JOIN room_statuses rs ON rcs.status_id = rs.id
LEFT JOIN booking_guests bg ON b.id = bg.booking_id
LEFT JOIN booking_pets bp ON b.id = bp.booking_id
WHERE p.payment_date >= (CURRENT_DATE - INTERVAL '12 month')  
GROUP BY
    report_month,
    rc.category_code,
    r.room_number,
    b.id,
    b.checkin_date,
    b.checkout_date,
    b.total_cost,
    b.discount_applied,
    p.id,
    p.amount,
    p.payment_method,
    promo_details,
    rs.status_code
ORDER BY report_month DESC, booking_gross_amount DESC;
