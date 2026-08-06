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
    p_checkin DATE,
    p_checkout DATE,
    p_category_id INT
)
RETURNS TABLE (
    room_id INT,
    room_number VARCHAR,
    category_code VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.room_number,
        rc.category_code
    FROM rooms r
    JOIN room_categories rc ON r.category_id = rc.id
    LEFT JOIN bookings b
        ON r.id = b.room_id
        AND b.checkin_date < p_checkout
        AND b.checkout_date > p_checkin
    WHERE rc.id = p_category_id
      AND r.is_active = TRUE
      AND b.id IS NULL;
END;
$$ LANGUAGE plpgsql STABLE;

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
