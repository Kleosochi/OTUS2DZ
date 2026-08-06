Печатная форма «Наряд» (как VIEW под печатную форму)

CREATE OR REPLACE VIEW v_work_order_form AS
SELECT
    b.id AS order_number,          -- считаем id бронирования номером наряда
    b.created_at::date AS order_date,
    NULL AS building,              -- если есть справочник корпусов — можно добавить JOIN
    NULL AS floor,                -- аналогично по этажу
    r.room_number AS room_number,
    r.room_number AS unit_name,    -- «помещение»
    COUNT(DISTINCT bg.guest_id) AS guests_count,
    COUNT(DISTINCT bp.pet_id) AS pets_count
FROM bookings b
JOIN rooms r ON b.room_id = r.id
LEFT JOIN booking_guests bg ON b.id = bg.booking_id
LEFT JOIN booking_pets bp ON b.id = bp.booking_id
GROUP BY
    b.id,
    b.created_at,
    r.room_number;
