INSERT INTO roles (role_name) VALUES ('admin'), ('cashier'), ('housekeeping');

INSERT INTO users (username, full_name, role_id) VALUES
('admin_user', 'Администратор', 1),
('cashier_user', 'Кассир', 2),
('housekeeper_user', 'Горничная', 3);

INSERT INTO room_categories (category_code, description, base_price_per_night) VALUES
('standard', 'Стандартный номер', 3500),
('suite', 'Люкс', 7000),
('family', 'Семейный номер', 5000);

INSERT INTO rooms (room_number, category_id, max_occupancy, allow_pets, is_active) VALUES
('101', 1, 2, TRUE, TRUE),
('102', 1, 2, FALSE, TRUE),
('201', 2, 3, TRUE, TRUE),
('301', 3, 4, TRUE, TRUE);

INSERT INTO room_statuses (status_code, description) VALUES
('free', 'Свободен'),
('occupied', 'Занят'),
('dirty', 'Грязный'),
('repair', 'В ремонте');

INSERT INTO room_current_state (room_id, status_id, updated_at)
SELECT id, (SELECT id FROM room_statuses WHERE status_code = 'free'), CURRENT_TIMESTAMP
FROM rooms;

INSERT INTO guests (first_name, last_name, phone, passport_data) VALUES
('Иван', 'Петров', '+79991112233', '{"series": "4500", "number": "123456"}'),
('Мария', 'Сидорова', '+79994445566', '{"series": "4501", "number": "654321"}');

INSERT INTO pets (guest_id, pet_type, pet_name, weight_kg) VALUES
(1, 'собака', 'Бим', 12.5),
(2, 'кошка', 'Муся', 4.3);

INSERT INTO discounts (promo_code, discount_percent, min_stay_nights, valid_from, valid_to, max_usage) VALUES
('WELCOME20', 20, 3, '2024-01-01', '2024-12-31', 100),
('SUMMER15', 15, 5, '2024-06-01', '2024-08-31', 50);
