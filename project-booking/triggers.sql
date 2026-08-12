1. автоматически ставить статус «занят» при создании бронирования
  
CREATE OR REPLACE FUNCTION trg_fn_update_room_status_on_booking()
RETURNS TRIGGER AS $$
DECLARE
    v_occupied_status_id INT;
BEGIN
    SELECT id INTO v_occupied_status_id
    FROM room_statuses
    WHERE status_code = 'occupied';

    IF v_occupied_status_id IS NULL THEN
        RAISE EXCEPTION 'Статус "occupied" не найден в room_statuses';
    END IF;

    INSERT INTO room_current_state (room_id, status_id, updated_at)
    VALUES (NEW.room_id, v_occupied_status_id, CURRENT_TIMESTAMP)
    ON CONFLICT (room_id) DO UPDATE SET
        status_id = v_occupied_status_id,
        updated_at = CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_room_status_on_booking
AFTER INSERT ON bookings
FOR EACH ROW
EXECUTE FUNCTION trg_fn_update_room_status_on_booking();

Устранение замечаний.

DROP TRIGGER IF EXISTS trg_update_room_status_on_booking ON bookings;
DROP FUNCTION IF EXISTS trg_fn_update_room_status_on_booking();

ALTER TABLE rooms
  ADD COLUMN current_state VARCHAR(50) NOT NULL DEFAULT 'available';

ALTER TABLE rooms
  ADD CONSTRAINT chk_current_state
    CHECK (current_state IN ('available','occupied','cleaning','maintenance','out_of_service'));

CREATE OR REPLACE FUNCTION trg_fn_on_check_in()
RETURNS TRIGGER AS $$
BEGIN

  CREATE OR REPLACE FUNCTION set_room_cleaning(p_room_id INT)
RETURNS VOID AS $$
BEGIN
  UPDATE rooms
  SET current_state = 'cleaning'
  WHERE room_id = p_room_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_fn_sync_room_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_room_state TEXT;
BEGIN
  IF OLD.booking_status IS DISTINCT FROM NEW.booking_status THEN
    CASE NEW.booking_status
      WHEN 'checked_in' THEN
        v_room_state := 'occupied';
      WHEN 'checked_out' THEN
        v_room_state := 'cleaning';
      ELSE
        -- ничего не делаем для confirmed/cancelled/pending
        RETURN NEW;
    END CASE;

    UPDATE rooms
    SET current_state = v_room_state
    WHERE room_id = NEW.room_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_room_on_booking_status
AFTER UPDATE OF booking_status ON bookings
FOR EACH ROW
EXECUTE FUNCTION trg_fn_sync_room_on_status_change();


  UPDATE rooms
  SET current_state = 'occupied'
  WHERE room_id = NEW.room_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_room_occupied(p_room_id INT)
RETURNS VOID AS $$
BEGIN
  UPDATE rooms
  SET current_state = 'occupied'
  WHERE room_id = p_room_id;
END;
$$ LANGUAGE plpgsql;


2. логировать изменения оплаты (для аудита и мониторинга)
CREATE OR REPLACE FUNCTION trg_fn_log_payment_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO reports_log (report_type, parameters, rows_returned)
        VALUES (
            'payment_insert',
            jsonb_build_object(
                'booking_id', NEW.booking_id,
                'amount', NEW.amount,
                'payment_method', NEW.payment_method,
                'transaction_rrn', NEW.transaction_rrn
            ),
            1
        );
    ELSIF TG_OP IN ('UPDATE', 'DELETE') THEN
        INSERT INTO reports_log (report_type, parameters, rows_returned)
        VALUES (
            CASE WHEN TG_OP = 'UPDATE' THEN 'payment_update' ELSE 'payment_delete' END,
            jsonb_build_object(
                'old_amount', COALESCE(OLD.amount, 0),
                'new_amount', COALESCE(NEW.amount, 0),
                'booking_id', COALESCE(NEW.booking_id, OLD.booking_id),
                'changed_at', CURRENT_TIMESTAMP
            ),
            1
        );
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_payment_changes
AFTER INSERT OR UPDATE OR DELETE ON payments
FOR EACH ROW
EXECUTE FUNCTION trg_fn_log_payment_changes();
