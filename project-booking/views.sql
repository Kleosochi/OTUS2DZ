1. Сводка по бронированию: номер, даты, кол-во гостей/питомцев, сумма, скидка
  
CREATE OR REPLACE VIEW v_booking_summary AS
SELECT
    b.id AS booking_id,
    r.room_number,
    r.category,
    b.checkin_date,
    b.checkout_date,
    COUNT(DISTINCT bg.guest_id) AS guests_count,
    COUNT(DISTINCT bp.pet_id) AS pets_count,
    SUM(p.amount) AS total_amount,
    COALESCE(SUM(p.discount_applied), 0) AS total_discount,
    b.status
FROM bookings b
JOIN rooms r ON b.room_id = r.id
LEFT JOIN booking_guests bg ON b.id = bg.booking_id
LEFT JOIN booking_pets bp ON b.id = bp.booking_id
LEFT JOIN payments p ON b.id = p.booking_id
GROUP BY b.id, r.room_number, r.category, b.checkin_date, b.checkout_date, b.status;

2. Занятость номеров по дням (для отчётов)
  
CREATE OR REPLACE VIEW v_room_occupancy AS
SELECT
    d.day,
    r.id AS room_id,
    r.room_number,
    r.category,
    rs.code AS status_code,
    COUNT(DISTINCT bg.guest_id) AS occupancy_guests,
    COUNT(DISTINCT bp.pet_id) AS occupancy_pets
FROM generate_series(
        (SELECT MIN(checkin_date) FROM bookings),
        (SELECT MAX(checkout_date) FROM bookings),
        INTERVAL '1 day'
    ) AS d(day)
CROSS JOIN rooms r
LEFT JOIN room_statuses rs ON r.status_id = rs.id
LEFT JOIN bookings b ON r.id = b.room_id
    AND d.day >= b.checkin_date
    AND d.day < b.checkout_date
LEFT JOIN booking_guests bg ON b.id = bg.booking_id
LEFT JOIN booking_pets bp ON b.id = bp.booking_id
GROUP BY d.day, r.id, r.room_number, r.category, rs.code;

3. Платежи с расшифровкой скидок

CREATE OR REPLACE VIEW v_payments_with_discounts AS
SELECT
    p.id,
    p.booking_id,
    p.amount,
    p.discount_applied,
    (p.amount + p.discount_applied) AS gross_amount,
    d.code AS discount_code,
    d.percent_discount,
    p.payment_date,
    p.payment_method,
    p.rrn
FROM payments p
LEFT JOIN discounts d ON p.discount_applied > 0; 
