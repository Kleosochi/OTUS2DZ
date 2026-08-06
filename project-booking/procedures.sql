1. Создание бронирования с валидацией

CREATE OR REPLACE PROCEDURE sp_create_booking(
    p_room_id INT,
    p_checkin DATE,
    p_checkout DATE,
    p_guest_ids INT[],
    p_pet_ids INT[]
) LANGUAGE plpgsql AS $$
DECLARE
    v_cost NUMERIC;
    v_booking_id INT;
    v_guest INT;      
    v_pet INT;        
BEGIN
    IF EXISTS (
        SELECT 1 FROM bookings
        WHERE room_id = p_room_id
          AND checkin_date < p_checkout
          AND checkout_date > p_checkin
    ) THEN
        RAISE EXCEPTION 'Номер уже занят на указанный период';
    END IF;

    SELECT SUM(rc.base_price_per_night) * (p_checkout - p_checkin)
    INTO v_cost
    FROM rooms r
    JOIN room_categories rc ON r.category_id = rc.id
    WHERE r.id = p_room_id;

    IF v_cost IS NULL THEN
        RAISE EXCEPTION 'Не удалось рассчитать стоимость: номер или категория не найдены';
    END IF;

    INSERT INTO bookings (room_id, checkin_date, checkout_date, total_cost)
    VALUES (p_room_id, p_checkin, p_checkout, v_cost)
    RETURNING id INTO v_booking_id;


    FOREACH v_guest IN ARRAY p_guest_ids LOOP
        INSERT INTO booking_guests (booking_id, guest_id, is_primary_guest)
        VALUES (v_booking_id, v_guest, FALSE);
    END LOOP;


    FOREACH v_pet IN ARRAY p_pet_ids LOOP
        INSERT INTO booking_pets (booking_id, pet_id)
        VALUES (v_booking_id, v_pet);
    END LOOP;
END;
$$;

2. Применение скидки к бронированию
CREATE OR REPLACE PROCEDURE sp_apply_discount(
    p_booking_id INT,
    p_promo_code VARCHAR
) LANGUAGE plpgsql AS $$
DECLARE
    v_discount_percent NUMERIC;
    v_original_cost NUMERIC;
    v_new_cost NUMERIC;
BEGIN
    SELECT total_cost INTO v_original_cost FROM bookings WHERE id = p_booking_id;

    SELECT discount_percent INTO v_discount_percent
    FROM discounts WHERE promo_code = p_promo_code;

    IF v_discount_percent IS NULL THEN
        RAISE EXCEPTION 'Промокод не найден или невалиден';
    END IF;

    v_new_cost := v_original_cost * (1 - v_discount_percent / 100.0);

    UPDATE bookings
    SET discount_applied = v_original_cost - v_new_cost,
        total_cost = v_new_cost,
        promo_details = jsonb_build_object('promo_code', p_promo_code, 'discount_percent', v_discount_percent)
    WHERE id = p_booking_id;
END;
$$;

3. Выезд гостя: обновление статуса номера
CREATE OR REPLACE PROCEDURE sp_checkout_booking(p_booking_id INT) LANGUAGE plpgsql AS $$
DECLARE
    v_room_id INT;
BEGIN
    SELECT room_id INTO v_room_id FROM bookings WHERE id = p_booking_id;

    UPDATE room_current_state
    SET status_id = (SELECT id FROM room_statuses WHERE status_code = 'dirty'),
        updated_at = CURRENT_TIMESTAMP
    WHERE room_id = v_room_id;

    INSERT INTO reports_log (report_type, parameters, rows_returned)
    VALUES ('checkout', jsonb_build_object('booking_id', p_booking_id), 1);
END;
$$;

4. Генерация ежедневного отчёта по заездам/выездам
CREATE OR REPLACE PROCEDURE sp_generate_daily_report(p_report_date DATE) LANGUAGE plpgsql AS $$
DECLARE
    v_rows INT;
BEGIN
    INSERT INTO reports_log (report_type, parameters, rows_returned)
    SELECT 'daily_occupancy',
           jsonb_build_object('report_date', p_report_date, 'category', rc.category_code),
           COUNT(*)
    FROM v_room_occupancy vo
    JOIN room_categories rc ON vo.category_code = rc.category_code
    WHERE vo.day = p_report_date
    GROUP BY rc.category_code;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RAISE NOTICE 'Сгенерировано строк отчёта: %', v_rows;
END;
$$;

5. Добавление гостя к бронированию
CREATE OR REPLACE PROCEDURE sp_add_guest_to_booking(
    p_booking_id INT,
    p_guest_id INT,
    p_is_primary BOOLEAN DEFAULT FALSE
) LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO booking_guests (booking_id, guest_id, is_primary_guest)
    VALUES (p_booking_id, p_guest_id, p_is_primary);
END;
$$;
