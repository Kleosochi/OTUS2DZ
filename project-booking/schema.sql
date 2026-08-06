1. Справочник ролей
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

2. Пользователи/сотрудники
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    full_name VARCHAR(200),
    role_id INT NOT NULL REFERENCES roles(id)
);

3. Категории номеров
CREATE TABLE room_categories (
    id SERIAL PRIMARY KEY,
    category_code VARCHAR(20) NOT NULL UNIQUE,
    description VARCHAR(255),
    base_price_per_night NUMERIC(10, 2) NOT NULL
);

4. Номера
CREATE TABLE rooms (
    id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL UNIQUE,
    category_id INT NOT NULL REFERENCES room_categories(id),
    max_occupancy INT NOT NULL,
    allow_pets BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

5. Статусы номеров
CREATE TABLE room_statuses (
    id SERIAL PRIMARY KEY,
    status_code VARCHAR(20) NOT NULL UNIQUE, 
    description VARCHAR(255)
);

6. Текущее состояние номера
CREATE TABLE room_current_state (
    room_id INT PRIMARY KEY REFERENCES rooms(id),
    status_id INT NOT NULL REFERENCES room_statuses(id),
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

7. Гости
CREATE TABLE guests (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    passport_data JSONB  
);

8. Питомцы
CREATE TABLE pets (
    id SERIAL PRIMARY KEY,
    guest_id INT NOT NULL REFERENCES guests(id),
    pet_type VARCHAR(50) NOT NULL,      
    pet_name VARCHAR(100),
    weight_kg NUMERIC(5, 2)
);

9. Бронирования
CREATE TABLE bookings (
    id SERIAL PRIMARY KEY,
    room_id INT NOT NULL REFERENCES rooms(id),
    checkin_date DATE NOT NULL,
    checkout_date DATE NOT NULL,
    total_cost NUMERIC(12, 2),
    discount_applied NUMERIC(6, 2),   
    promo_details JSONB,                
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_dates CHECK (checkout_date > checkin_date)
);

10. Связь бронирования и гостей
CREATE TABLE booking_guests (
    booking_id INT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    guest_id INT NOT NULL REFERENCES guests(id),
    is_primary_guest BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (booking_id, guest_id)
);

11. Связь бронирования и питомцев
CREATE TABLE booking_pets (
    booking_id INT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    pet_id INT NOT NULL REFERENCES pets(id),
    PRIMARY KEY (booking_id, pet_id)
);

12. Скидки/промокоды
CREATE TABLE discounts (
    id SERIAL PRIMARY KEY,
    promo_code VARCHAR(50) NOT NULL UNIQUE,
    discount_percent NUMERIC(5, 2) NOT NULL,
    min_stay_nights INT,
    valid_from DATE,
    valid_to DATE,
    max_usage INT
);

13. Платежи
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    booking_id INT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    amount NUMERIC(12, 2) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payment_method VARCHAR(50),        
    transaction_rrn VARCHAR(50)       
);

14. Журнал отчётов (для мониторинга)
CREATE TABLE reports_log (
    id SERIAL PRIMARY KEY,
    report_type VARCHAR(100) NOT NULL,
    generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    parameters JSONB,
    rows_returned INT
);
