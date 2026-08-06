Отчёт «Номера — заезды и выезды» (как VIEW)

CREATE OR REPLACE VIEW v_room_stays_report AS
SELECT
    r.room_number,
    rc.category_code,
    rs.status_code = 'dirty' AS is_dirty,
    COUNT(DISTINCT bg.guest_id) AS guests_count,
    COUNT(DISTINCT bp.pet_id) AS pets_count,
    b.checkout_date,
    LEAD(b.checkin_date) OVER (PARTITION BY r.id ORDER BY b.checkin_date) AS next_checkin,
    r.max_occupancy AS total_places,
    COUNT(DISTINCT bg.guest_id) AS occupied_places
FROM rooms r
JOIN room_categories rc ON r.category_id = rc.id
LEFT JOIN room_current_state rcs ON r.id = rcs.room_id
LEFT JOIN room_statuses rs ON rcs.status_id = rs.id
LEFT JOIN bookings b ON r.id = b.room_id
LEFT JOIN booking_guests bg ON b.id = bg.booking_id
LEFT JOIN booking_pets bp ON b.id = bp.booking_id
WHERE r.is_active = TRUE
GROUP BY
    r.id,
    r.room_number,
    rc.category_code,
    rs.status_code,
    b.id,
    b.checkout_date;
