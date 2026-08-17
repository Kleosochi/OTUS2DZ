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
    r.id AS room_id,
    r.room_number,
    r.current_state AS physical_state,  -- физическое состояние (уборка, ремонт и т.п.)
    d.occupation_date,
    EXISTS (
        SELECT 1
        FROM bookings b
        WHERE b.room_id = r.id
          AND b.booking_status IN ('confirmed', 'checked_in', 'checked_out')
          AND d.occupation_date >= b.checkin_date
          AND d.occupation_date < b.checkout_date
    ) AS is_occupied,
    (
        SELECT b.id
        FROM bookings b
        WHERE b.room_id = r.id
          AND b.booking_status IN ('confirmed', 'checked_in', 'checked_out')
          AND d.occupation_date >= b.checkin_date
          AND d.occupation_date < b.checkout_date
        LIMIT 1
    ) AS active_booking_id
FROM rooms r
CROSS JOIN generate_series(
    CURRENT_DATE - INTERVAL '30 days',
    CURRENT_DATE + INTERVAL '90 days',
    INTERVAL '1 day'
) AS d(occupation_date);

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
