1. Сводка по бронированию: номер, даты, гости, питомцы, стоимость, скидка
  
CREATE OR REPLACE VIEW v_booking_summary AS
SELECT
    b.id AS booking_id,
    r.room_number,
    rc.category_code AS room_category,
    b.checkin_date,
    b.checkout_date,
    COUNT(bg.guest_id) AS total_guests,
    COUNT(bp.pet_id) AS total_pets,
    b.total_cost,
    b.discount_applied,
    rs.status_code AS current_room_status
FROM bookings b
JOIN rooms r ON b.room_id = r.id
JOIN room_categories rc ON r.category_id = rc.id
LEFT JOIN room_current_state rcs ON r.id = rcs.room_id
LEFT JOIN room_statuses rs ON rcs.status_id = rs.id
LEFT JOIN booking_guests bg ON b.id = bg.booking_id
LEFT JOIN booking_pets bp ON b.id = bp.booking_id
GROUP BY b.id, r.room_number, rc.category_code, b.checkin_date, b.checkout_date,
         b.total_cost, b.discount_applied, rs.status_code;

2. Занятость номеров по дням (агрегация по датам)
CREATE OR REPLACE VIEW v_room_occupancy AS
SELECT
    d.day,
    r.id AS room_id,
    r.room_number,
    rc.category_code,
    COUNT(DISTINCT bg.guest_id) AS guests_count,
    COUNT(DISTINCT bp.pet_id) AS pets_count,
    CASE WHEN rcs.status_id IN (
            SELECT id FROM room_statuses WHERE status_code IN ('occupied', 'dirty')
         ) THEN TRUE ELSE FALSE END AS is_occupied
FROM generate_series(
        (SELECT MIN(checkin_date) FROM bookings),
        (SELECT MAX(checkout_date) FROM bookings),
        INTERVAL '1 day'
     ) AS d(day)
CROSS JOIN rooms r
LEFT JOIN bookings b ON r.id = b.room_id
    AND d.day >= b.checkin_date AND d.day < b.checkout_date
LEFT JOIN room_categories rc ON r.category_id = rc.id
LEFT JOIN room_current_state rcs ON r.id = rcs.room_id
LEFT JOIN booking_guests bg ON b.id = bg.booking_id
LEFT JOIN booking_pets bp ON b.id = bp.booking_id
WHERE r.is_active = TRUE
GROUP BY d.day, r.id, r.room_number, rc.category_code, rcs.status_id;

3. Детализация оплат с расшифровкой скидок
CREATE OR REPLACE VIEW v_payments_with_discounts AS
SELECT
    p.id AS payment_id,
    p.booking_id,
    p.amount,
    p.payment_date,
    p.payment_method,
    p.transaction_rrn,
    bs.total_cost,
    bs.discount_applied AS discount_amount,
    (bs.total_cost - COALESCE(bs.discount_applied, 0)) AS net_cost
FROM payments p
JOIN v_booking_summary bs ON p.booking_id = bs.booking_id;
