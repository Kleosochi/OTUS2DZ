CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role_id INT NOT NULL REFERENCES roles(id),
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE room_statuses (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,     
    description VARCHAR(100) NOT NULL
);

CREATE TABLE rooms (
    id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,          
    capacity INT NOT NULL CHECK (capacity > 0),
    allows_pets BOOLEAN DEFAULT FALSE,
    status_id INT NOT NULL REFERENCES room_statuses(id),
    price_per_night NUMERIC(10,2) NOT NULL CHECK (price_per_night >= 0)
);


CREATE TABLE guests (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(30),
    email VARCHAR(100),
    passport_data JSONB                   
);

CREATE TABLE pets (
    id SERIAL PRIMARY KEY,
    guest_id INT NOT NULL REFERENCES guests(id),
    pet_type VARCHAR(50) NOT NULL,         
    pet_name VARCHAR(100),
    weight_kg NUMERIC(5,2)
);


CREATE TABLE bookings (
    id SERIAL PRIMARY KEY,
    room_id INT NOT NULL REFERENCES rooms(id),
    checkin_date DATE NOT NULL,
    checkout_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'confirmed', 
    promo_details JSONB,                    
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE booking_guests (
    booking_id INT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    guest_id INT NOT NULL REFERENCES guests(id),
    PRIMARY KEY (booking_id, guest_id)
);

CREATE TABLE booking_pets (
    booking_id INT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    pet_id INT NOT NULL REFERENCES pets(id),
    PRIMARY KEY (booking_id, pet_id)
);


CREATE TABLE discounts (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    percent_discount NUMERIC(5,2) CHECK (percent_discount BETWEEN 0 AND 100),
    valid_from DATE,
    valid_to DATE
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    booking_id INT NOT NULL REFERENCES bookings(id),
    amount NUMERIC(10,2) NOT NULL,
    discount_applied NUMERIC(10,2) DEFAULT 0,
    payment_date TIMESTAMP NOT NULL DEFAULT NOW(),
    payment_method VARCHAR(50),           
    rrn VARCHAR(50)                       
);


CREATE TABLE reports_log (
    id SERIAL PRIMARY KEY,
    report_name VARCHAR(100) NOT NULL,
    generated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    generated_by INT REFERENCES users(id),
    params JSONB
);


CREATE INDEX idx_bookings_checkin ON bookings(checkin_date);
CREATE INDEX idx_bookings_checkout ON bookings(checkout_date);
CREATE INDEX idx_rooms_category ON rooms(category);
CREATE INDEX idx_payments_booking_id ON payments(booking_id);
CREATE INDEX idx_guests_full_name ON guests(full_name);
