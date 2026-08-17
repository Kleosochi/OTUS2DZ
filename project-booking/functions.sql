1. Расчёт стоимости проживания с учётом скидки

CREATE OR REPLACE FUNCTION fn_calculate_stay_cost(
    p_checkin DATE,
    p_checkout DATE,
    p_category_id INT,
    p_promo_code VARCHAR(50)
) RETURNS NUMERIC AS $$
DECLARE
    v_nights INT;
    v_base_price NUMERIC;
    v_discount_percent NUMERIC;
    v_total NUMERIC;
BEGIN
    IF p_checkout <= p_checkin THEN
        RAISE EXCEPTION 'Дата выезда должна быть позже даты заезда';
    END IF;

    v_nights := (p_checkout - p_checkin);

    SELECT base_price_per_night
    INTO v_base_price
    FROM room_categories
    WHERE id = p_category_id;


    IF v_base_price IS NULL THEN
        RAISE EXCEPTION 'Категория номера с id=% не найдена', p_category_id;
    END IF;

    v_total := v_nights * v_base_price;


    SELECT discount_percent
    INTO v_discount_percent
    FROM discounts
    WHERE promo_code = p_promo_code
      AND (
          (valid_from IS NULL AND valid_to IS NULL)
          OR (p_checkin BETWEEN valid_from AND valid_to)
      )
      AND v_nights >= COALESCE(min_stay_nights, 0);

    IF v_discount_percent IS NOT NULL THEN
        v_total := v_total * (1 - v_discount_percent / 100.0);
    END IF;

    RETURN ROUND(v_total, 2);
END;
$$ LANGUAGE plpgsql STABLE;  

2. Проверка доступности номера на период

CREATE OR REPLACE FUNCTION fn_get_room_availability(
    p_checkin_date DATE,
    p_checkout_date DATE
)
RETURNS TABLE (
    room_id INT,
    room_number VARCHAR,
    category_code VARCHAR,
    base_price_per_night NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.room_number,
        rc.category_code,
        rc.base_price_per_night
    FROM rooms r
    JOIN room_categories rc ON r.category_id = rc.id
    WHERE r.is_active = TRUE
      AND NOT EXISTS (
          SELECT 1
          FROM bookings b
          WHERE b.room_id = r.id
            AND b.booking_status IN ('confirmed', 'checked_in', 'checked_out')
            AND (
                (b.checkin_date < p_checkout_date)
                AND (b.checkout_date > p_checkin_date)
            )
      );
END;
$$ LANGUAGE plpgsql;

3.  Извлечение промокода из JSON
CREATE OR REPLACE FUNCTION fn_extract_json_promo_details(promo_data JSONB)
RETURNS TABLE (promo_code VARCHAR, discount_percent NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (promo_data->>'promo_code')::VARCHAR,
        (promo_data->>'discount_percent')::NUMERIC;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

4. Функция поиска свободных номеров на диапазон

CREATE OR REPLACE FUNCTION find_available_rooms(
  p_check_in  DATE,
  p_check_out DATE
)
RETURNS TABLE (
  room_id        INT,
  room_number    VARCHAR,
  category       VARCHAR,
  days_available INT
) AS $$
BEGIN
  RETURN QUERY
  WITH requested_dates AS (
    SELECT generate_series(p_check_in, p_check_out, INTERVAL '1 day')::date AS d
  ),
  blocked_days AS (
    SELECT
      u.room_id,
      d.d AS blocked_date
    FROM room_unavailability u
    JOIN requested_dates d ON d.d BETWEEN u.date_from AND u.date_to
  ),
  booked_days AS (
    SELECT
      b.room_id,
      d.d AS booked_date
    FROM bookings b
    JOIN requested_dates d ON d.d BETWEEN b.checkin_date AND b.checkout_date
    WHERE b.booking_status IN ('confirmed', 'checked_in')
  ),
  occupied_days AS (
    SELECT room_id, blocked_date AS date_ref FROM blocked_days
    UNION
    SELECT room_id, booked_date FROM booked_days
  ),
  total_requested_days AS (
    SELECT COUNT(*) AS cnt FROM requested_dates
  )
  SELECT
    r.room_id,
    r.room_number,
    r.category,
    (SELECT cnt FROM total_requested_days) - COUNT(o.date_ref) AS days_available
  FROM rooms r
  LEFT JOIN occupied_days o ON r.room_id = o.room_id
  GROUP BY r.room_id, r.room_number, r.category
  HAVING (SELECT cnt FROM total_requested_days) - COUNT(o.date_ref) = (SELECT cnt FROM total_requested_days);
END;
$$ LANGUAGE plpgsql;

5. Создаём функцию вместо процедуры.

CREATE OR REPLACE FUNCTION fn_create_booking(
    p_room_id INT,
    p_checkin_date DATE,
    p_checkout_date DATE,
    p_total_cost NUMERIC,
    p_discount_percent NUMERIC DEFAULT 0,
    p_promo_details JSONB DEFAULT '{}'::jsonb
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_overlap_count INT;
    v_booking_id INT;
BEGIN
    SELECT COUNT(*) INTO v_overlap_count
    FROM bookings b
    WHERE b.room_id = p_room_id
      AND b.booking_status IN ('confirmed', 'checked_in', 'checked_out')
      AND (b.checkin_date < p_checkout_date)
      AND (b.checkout_date > p_checkin_date);

    IF v_overlap_count > 0 THEN
        RAISE EXCEPTION 'Номер уже занят на указанные даты (найдено пересечений: %).', v_overlap_count;
    END IF;

    INSERT INTO bookings (
        room_id, checkin_date, checkout_date, total_cost,
        discount_applied, promo_details, booking_status
    )
    VALUES (
        p_room_id, p_checkin_date, p_checkout_date, p_total_cost,
        p_discount_percent, p_promo_details, 'confirmed'
    )
    RETURNING id INTO v_booking_id;

    RETURN v_booking_id;
END;
$$;
