1. Расчёт стоимости проживания с учётом скидки
  
CREATE OR REPLACE FUNCTION fn_calculate_stay_cost(
    p_checkin DATE,
    p_checkout DATE,
    p_room_category VARCHAR,
    p_discount_percent NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
    v_price_per_night NUMERIC;
    v_nights INT;
    v_base_cost NUMERIC;
BEGIN
    SELECT price_per_night INTO v_price_per_night
    FROM rooms
    WHERE category = p_room_category
    LIMIT 1;

    IF v_price_per_night IS NULL THEN
        RAISE EXCEPTION 'Категория номера не найдена';
    END IF;

    v_nights := (p_checkout - p_checkin);
    IF v_nights <= 0 THEN
        RAISE EXCEPTION 'Дата выезда должна быть позже даты заезда';
    END IF;

    v_base_cost := v_price_per_night * v_nights;
    RETURN v_base_cost * (1 - p_discount_percent / 100.0);
END;
$$ LANGUAGE plpgsql;

2. Проверка доступности номера на период
  
CREATE OR REPLACE FUNCTION fn_get_room_availability(
    p_checkin DATE,
    p_checkout DATE,
    p_category VARCHAR
) RETURNS SETOF rooms AS $$
BEGIN
    RETURN QUERY
    SELECT r.*
    FROM rooms r
    WHERE r.category = p_category
      AND r.status_id IN (
          SELECT id FROM room_statuses WHERE code = 'free'
      )
      AND NOT EXISTS (
          SELECT 1
          FROM bookings b
          WHERE b.room_id = r.id
            AND b.checkin_date < p_checkout
            AND b.checkout_date > p_checkin
      );
END;
$$ LANGUAGE plpgsql;

3. Извлечение промокода из JSON
CREATE OR REPLACE FUNCTION fn_extract_json_promo_details(
    p_promo_data JSONB
) RETURNS TABLE (promo_code VARCHAR, percent_discount NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (p_promo_data ->> 'code') AS promo_code,
        (p_promo_data ->> 'percent_discount')::NUMERIC AS percent_discount
    WHERE p_promo_data IS NOT NULL;
END;
$$ LANGUAGE plpgsql;
