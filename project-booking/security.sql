CREATE ROLE role_admin;
CREATE ROLE role_cashier;
CREATE ROLE role_housekeeping;

1. Права администратора (полный доступ)
GRANT ALL PRIVILEGES ON SCHEMA public TO role_admin;
GRANT ALL ON ALL TABLES IN SCHEMA public TO role_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO role_admin;

2. Права кассира (только платежи, скидки, отчёты; без прямого доступа к персональным данным гостей, доступ только через представления, где данные обезличены или агрегированы)
GRANT USAGE ON SCHEMA public TO role_cashier;
GRANT SELECT, INSERT, UPDATE, DELETE ON payments, discounts, reports_log TO role_cashier;
GRANT SELECT ON v_payments_with_discounts, v_booking_summary TO role_cashier;

3. Права горничной (статусы номеров, задачи; без доступа к платежам и гостям)
GRANT USAGE ON SCHEMA public TO role_housekeeping;
GRANT SELECT, UPDATE ON rooms, room_current_state, room_statuses TO role_housekeeping;
GRANT EXECUTE ON PROCEDURE sp_checkout_booking TO role_housekeeping;

Пример создания пользователя и назначения роли
CREATE USER user_cashier WITH PASSWORD 'strong_password_123';
GRANT role_cashier TO user_cashier;
