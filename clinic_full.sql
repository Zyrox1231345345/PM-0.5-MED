-- =================================================================
-- Дамп БД "clinic" для информационной системы "Поликлиника"
-- Производственная практика ПМ.05, Звягенцев В.О., группа ДКИП-403
--
-- СУБД: MySQL 8.x (XAMPP, phpMyAdmin)
-- Кодировка: utf8mb4
--
-- ИНСТРУКЦИЯ ПО ИМПОРТУ ЧЕРЕЗ phpMyAdmin:
--   Способ 1 (рекомендуется — через "SQL" вкладку):
--     1. Открыть phpMyAdmin → выбрать БД (или сначала создать "clinic")
--     2. Перейти на вкладку "SQL"
--     3. Открыть этот файл в любом редакторе, скопировать всё содержимое
--     4. Вставить в поле SQL-запроса
--     5. ВНИЗУ страницы найти поле "Разделитель" / "Delimiter" — оставить ;
--        (DELIMITER-команды внутри файла обработаются phpMyAdmin корректно
--         в современных версиях ≥ 4.7).
--     6. Нажать "Вперёд" / "Go"
--
--   Способ 2 (через командную строку MySQL — самый надёжный):
--     mysql -u root -p < clinic_full.sql
--
--   Способ 3 (Import в phpMyAdmin):
--     1. Открыть phpMyAdmin → Import
--     2. Выбрать файл, кодировка utf8
--     3. ЕСЛИ возникнет ошибка на DELIMITER — использовать Способ 2.
-- =================================================================

-- При повторном импорте — снести старую БД
DROP DATABASE IF EXISTS clinic;

CREATE DATABASE clinic
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE clinic;

-- =================================================================
-- 1. ТАБЛИЦЫ
-- =================================================================

-- 1.1 Роли пользователей
CREATE TABLE roles (
    role_id     INT          NOT NULL AUTO_INCREMENT,
    role_name   VARCHAR(50)  NOT NULL,
    description VARCHAR(255),
    PRIMARY KEY (role_id),
    UNIQUE KEY uq_role_name (role_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 1.2 Пользователи системы
CREATE TABLE users (
    user_id        INT          NOT NULL AUTO_INCREMENT,
    login          VARCHAR(80)  NOT NULL,
    password_salt  VARCHAR(32)  NOT NULL,
    password_hash  VARCHAR(64)  NOT NULL,
    full_name      VARCHAR(150) NOT NULL,
    email          VARCHAR(150) NOT NULL,
    role_id        INT          NOT NULL,
    is_active      TINYINT(1)   NOT NULL DEFAULT 1,
    created_at     DATETIME     NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_users_login (login),
    UNIQUE KEY uq_users_email (email),
    CONSTRAINT fk_users_role
        FOREIGN KEY (role_id) REFERENCES roles (role_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 1.3 Справочник специализаций
CREATE TABLE specializations (
    specialization_id INT          NOT NULL AUTO_INCREMENT,
    name              VARCHAR(100) NOT NULL,
    description       VARCHAR(255),
    PRIMARY KEY (specialization_id),
    UNIQUE KEY uq_spec_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 1.4 Врачи (1:1 с users)
CREATE TABLE doctors (
    doctor_id         INT NOT NULL AUTO_INCREMENT,
    user_id           INT NOT NULL,
    specialization_id INT NOT NULL,
    cabinet_number    VARCHAR(10),
    experience_years  INT NOT NULL DEFAULT 0,
    PRIMARY KEY (doctor_id),
    UNIQUE KEY uq_doctors_user (user_id),
    CONSTRAINT fk_doctors_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_doctors_spec
        FOREIGN KEY (specialization_id) REFERENCES specializations (specialization_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_experience CHECK (experience_years >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 1.5 Пациенты
CREATE TABLE patients (
    patient_id    INT          NOT NULL AUTO_INCREMENT,
    full_name     VARCHAR(150) NOT NULL,
    birth_date    DATE         NOT NULL,
    phone         VARCHAR(20),
    policy_number VARCHAR(20)  NOT NULL,
    address       VARCHAR(255),
    created_at    DATETIME     NOT NULL DEFAULT NOW(),
    PRIMARY KEY (patient_id),
    UNIQUE KEY uq_patients_policy (policy_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 1.6 Записи на приём
CREATE TABLE appointments (
    appointment_id   INT         NOT NULL AUTO_INCREMENT,
    patient_id       INT         NOT NULL,
    doctor_id        INT         NOT NULL,
    appointment_date DATETIME    NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    complaint        TEXT,
    created_by       INT         NOT NULL,
    created_at       DATETIME    NOT NULL DEFAULT NOW(),
    updated_at       DATETIME,
    PRIMARY KEY (appointment_id),
    CONSTRAINT fk_app_patient
        FOREIGN KEY (patient_id) REFERENCES patients (patient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_app_doctor
        FOREIGN KEY (doctor_id) REFERENCES doctors (doctor_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_app_creator
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_status
        CHECK (status IN ('scheduled','in_progress','completed','cancelled'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 1.7 Диагнозы
CREATE TABLE diagnoses (
    diagnosis_id    INT         NOT NULL AUTO_INCREMENT,
    appointment_id  INT         NOT NULL,
    diagnosis_code  VARCHAR(10) NOT NULL,
    description     TEXT,
    recommendations TEXT,
    created_at      DATETIME    NOT NULL DEFAULT NOW(),
    PRIMARY KEY (diagnosis_id),
    CONSTRAINT fk_diag_app
        FOREIGN KEY (appointment_id) REFERENCES appointments (appointment_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 1.8 Журнал смены статусов
CREATE TABLE appointment_history (
    history_id     INT         NOT NULL AUTO_INCREMENT,
    appointment_id INT         NOT NULL,
    changed_by     INT,
    old_status     VARCHAR(20),
    new_status     VARCHAR(20) NOT NULL,
    changed_at     DATETIME    NOT NULL DEFAULT NOW(),
    note           TEXT,
    PRIMARY KEY (history_id),
    CONSTRAINT fk_hist_app
        FOREIGN KEY (appointment_id) REFERENCES appointments (appointment_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_hist_user
        FOREIGN KEY (changed_by) REFERENCES users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =================================================================
-- 2. ИНДЕКСЫ
-- =================================================================
CREATE INDEX idx_app_patient ON appointments (patient_id);
CREATE INDEX idx_app_doctor  ON appointments (doctor_id);
CREATE INDEX idx_app_status  ON appointments (status, appointment_date);
CREATE INDEX idx_hist_app    ON appointment_history (appointment_id);

-- =================================================================
-- 3. ТЕСТОВЫЕ ДАННЫЕ
-- =================================================================
-- ВАЖНО: пароли всех тестовых пользователей — "test12345"
-- Соль и хэш сгенерированы под него (SHA-256(salt + "test12345"))
-- Пары соль/хэш можно перегенерировать утилитой PasswordTool
-- из проекта приложения (см. README).
-- =================================================================

INSERT INTO roles (role_name, description) VALUES
    ('admin',     'Администратор системы'),
    ('registrar', 'Регистратор поликлиники'),
    ('doctor',    'Врач — ведёт приём пациентов');

INSERT INTO specializations (name, description) VALUES
    ('Терапевт',  'Врач общей практики'),
    ('Кардиолог', 'Заболевания сердечно-сосудистой системы'),
    ('Невролог',  'Заболевания нервной системы'),
    ('Хирург',    'Хирургические вмешательства и осмотры');

-- Все пароли = "test12345", соль уникальна для каждого
INSERT INTO users (login, password_salt, password_hash, full_name, email, role_id, is_active) VALUES
    ('admin',
     '0123456789abcdef0123456789abcdef',
     SHA2(CONCAT('0123456789abcdef0123456789abcdef','test12345'), 256),
     'Звягенцев Владислав Олегович', 'admin@clinic.ru', 1, 1),
    ('registrar1',
     'fedcba9876543210fedcba9876543210',
     SHA2(CONCAT('fedcba9876543210fedcba9876543210','test12345'), 256),
     'Иванова Анна Петровна', 'reg1@clinic.ru', 2, 1),
    ('petrov',
     '11223344556677889900aabbccddeeff',
     SHA2(CONCAT('11223344556677889900aabbccddeeff','test12345'), 256),
     'Петров Сергей Иванович', 'petrov@clinic.ru', 3, 1),
    ('sidorova',
     'ffeeddccbbaa00998877665544332211',
     SHA2(CONCAT('ffeeddccbbaa00998877665544332211','test12345'), 256),
     'Сидорова Елена Викторовна', 'sidorova@clinic.ru', 3, 1);

INSERT INTO doctors (user_id, specialization_id, cabinet_number, experience_years) VALUES
    (3, 1, '101', 12),
    (4, 2, '205', 8);

INSERT INTO patients (full_name, birth_date, phone, policy_number, address) VALUES
    ('Кузнецов Дмитрий Александрович', '1985-03-12', '+7-921-111-22-33', '7700123456789012', 'г. Санкт-Петербург, ул. Ленина, д. 5'),
    ('Морозова Ольга Николаевна',     '1992-07-24', '+7-921-444-55-66', '7700987654321098', 'г. Санкт-Петербург, пр. Невский, д. 18'),
    ('Соколов Игорь Валерьевич',      '1978-11-03', '+7-921-777-88-99', '7700555444333222', 'г. Санкт-Петербург, ул. Садовая, д. 42');

INSERT INTO appointments (patient_id, doctor_id, appointment_date, status, complaint, created_by) VALUES
    (1, 1, '2026-05-12 09:00:00', 'scheduled',   'Боль в горле, кашель',           2),
    (2, 2, '2026-05-12 10:30:00', 'in_progress', 'Учащённое сердцебиение, одышка', 2),
    (3, 1, '2026-05-10 14:00:00', 'completed',   'Профилактический осмотр',        2);

INSERT INTO diagnoses (appointment_id, diagnosis_code, description, recommendations) VALUES
    (3, 'Z00.0', 'Общий медицинский осмотр — отклонений не выявлено', 'Повторный осмотр через 12 месяцев');

INSERT INTO appointment_history (appointment_id, changed_by, old_status, new_status, note) VALUES
    (3, 3, 'scheduled',   'in_progress', 'Пациент зашёл в кабинет'),
    (3, 3, 'in_progress', 'completed',   'Приём завершён, диагноз внесён');

-- =================================================================
-- 4. ПРЕДСТАВЛЕНИЯ (VIEW)
-- =================================================================

CREATE OR REPLACE VIEW v_appointments_full AS
SELECT
    a.appointment_id,
    a.appointment_date,
    a.status,
    a.complaint,
    p.patient_id,
    p.full_name      AS patient_name,
    p.policy_number,
    p.birth_date     AS patient_birth_date,
    d.doctor_id,
    u_doc.full_name  AS doctor_name,
    s.name           AS specialization,
    d.cabinet_number,
    u_reg.full_name  AS registered_by,
    a.created_at,
    a.updated_at
FROM appointments a
JOIN patients        p     ON a.patient_id        = p.patient_id
JOIN doctors         d     ON a.doctor_id         = d.doctor_id
JOIN users           u_doc ON d.user_id           = u_doc.user_id
JOIN specializations s     ON d.specialization_id = s.specialization_id
JOIN users           u_reg ON a.created_by        = u_reg.user_id;

CREATE OR REPLACE VIEW v_doctor_workload AS
SELECT
    d.doctor_id,
    u.full_name AS doctor_name,
    s.name      AS specialization,
    d.cabinet_number,
    COUNT(CASE WHEN a.status = 'scheduled'   THEN 1 END) AS scheduled_count,
    COUNT(CASE WHEN a.status = 'in_progress' THEN 1 END) AS active_count,
    COUNT(CASE WHEN a.status = 'completed'   THEN 1 END) AS completed_count,
    COUNT(CASE WHEN a.status = 'cancelled'   THEN 1 END) AS cancelled_count,
    COUNT(a.appointment_id)                              AS total_count
FROM doctors d
JOIN users u           ON d.user_id           = u.user_id
JOIN specializations s ON d.specialization_id = s.specialization_id
LEFT JOIN appointments a ON d.doctor_id      = a.doctor_id
GROUP BY d.doctor_id, u.full_name, s.name, d.cabinet_number;

-- =================================================================
-- 5. ХРАНИМЫЕ ПРОЦЕДУРЫ
-- =================================================================

DELIMITER $$

CREATE PROCEDURE sp_create_appointment(
    IN  p_patient_id        INT,
    IN  p_doctor_id         INT,
    IN  p_appointment_date  DATETIME,
    IN  p_complaint         TEXT,
    IN  p_created_by        INT,
    OUT p_new_id            INT
)
BEGIN
    IF EXISTS (
        SELECT 1 FROM appointments
        WHERE doctor_id = p_doctor_id
          AND appointment_date = p_appointment_date
          AND status <> 'cancelled'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Врач уже занят в указанное время';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM patients WHERE patient_id = p_patient_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Пациент не найден';
    END IF;

    INSERT INTO appointments (
        patient_id, doctor_id, appointment_date,
        status, complaint, created_by
    )
    VALUES (
        p_patient_id, p_doctor_id, p_appointment_date,
        'scheduled', p_complaint, p_created_by
    );

    SET p_new_id = LAST_INSERT_ID();
END$$

CREATE PROCEDURE sp_change_appointment_status(
    IN p_appointment_id INT,
    IN p_new_status     VARCHAR(20),
    IN p_user_id        INT,
    IN p_note           TEXT
)
BEGIN
    DECLARE v_old_status VARCHAR(20);

    SELECT status INTO v_old_status
    FROM appointments
    WHERE appointment_id = p_appointment_id;

    IF v_old_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Запись на приём не найдена';
    END IF;

    IF v_old_status = p_new_status THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Запись уже находится в этом статусе';
    END IF;

    UPDATE appointments
    SET    status = p_new_status
    WHERE  appointment_id = p_appointment_id;

    INSERT INTO appointment_history (
        appointment_id, changed_by, old_status, new_status, note
    )
    VALUES (
        p_appointment_id, p_user_id, v_old_status, p_new_status, p_note
    );
END$$

CREATE PROCEDURE sp_register_patient(
    IN  p_full_name     VARCHAR(150),
    IN  p_birth_date    DATE,
    IN  p_phone         VARCHAR(20),
    IN  p_policy_number VARCHAR(20),
    IN  p_address       VARCHAR(255),
    OUT p_new_id        INT
)
BEGIN
    IF EXISTS (SELECT 1 FROM patients WHERE policy_number = p_policy_number) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Пациент с таким полисом уже зарегистрирован';
    END IF;

    IF p_birth_date > CURRENT_DATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Дата рождения не может быть в будущем';
    END IF;

    INSERT INTO patients (full_name, birth_date, phone, policy_number, address)
    VALUES (p_full_name, p_birth_date, p_phone, p_policy_number, p_address);

    SET p_new_id = LAST_INSERT_ID();
END$$

CREATE PROCEDURE sp_register_user(
    IN  p_login     VARCHAR(80),
    IN  p_salt      VARCHAR(32),
    IN  p_hash      VARCHAR(64),
    IN  p_full_name VARCHAR(150),
    IN  p_email     VARCHAR(150),
    IN  p_role_id   INT,
    OUT p_new_id    INT
)
BEGIN
    IF EXISTS (SELECT 1 FROM users WHERE login = p_login) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Логин уже занят';
    END IF;

    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Email уже зарегистрирован';
    END IF;

    INSERT INTO users (login, password_salt, password_hash,
                       full_name, email, role_id, is_active)
    VALUES (p_login, p_salt, p_hash,
            p_full_name, p_email, p_role_id, 1);

    SET p_new_id = LAST_INSERT_ID();
END$$

-- =================================================================
-- 6. ТРИГГЕРЫ
-- =================================================================

CREATE TRIGGER trg_log_status_change
AFTER UPDATE ON appointments
FOR EACH ROW
BEGIN
    IF NOT (OLD.status <=> NEW.status) THEN
        INSERT INTO appointment_history (
            appointment_id, changed_by, old_status, new_status, note
        )
        VALUES (
            OLD.appointment_id, NULL, OLD.status, NEW.status,
            'Автоматическая запись триггера'
        );
    END IF;
END$$

CREATE TRIGGER trg_update_timestamp
BEFORE UPDATE ON appointments
FOR EACH ROW
BEGIN
    SET NEW.updated_at = NOW();
END$$

DELIMITER ;

-- =================================================================
-- 7. РОЛИ И УЧЁТНЫЕ ЗАПИСИ MySQL
-- =================================================================

CREATE ROLE IF NOT EXISTS 'clinic_readonly';
CREATE ROLE IF NOT EXISTS 'clinic_operator';
CREATE ROLE IF NOT EXISTS 'clinic_admin';

GRANT SELECT ON clinic.* TO 'clinic_readonly';

GRANT SELECT, INSERT, UPDATE ON clinic.patients            TO 'clinic_operator';
GRANT SELECT, INSERT, UPDATE ON clinic.appointments        TO 'clinic_operator';
GRANT SELECT, INSERT, UPDATE ON clinic.diagnoses           TO 'clinic_operator';
GRANT SELECT, INSERT         ON clinic.appointment_history TO 'clinic_operator';
GRANT SELECT ON clinic.roles                  TO 'clinic_operator';
GRANT SELECT ON clinic.users                  TO 'clinic_operator';
GRANT SELECT ON clinic.specializations        TO 'clinic_operator';
GRANT SELECT ON clinic.doctors                TO 'clinic_operator';
GRANT SELECT ON clinic.v_appointments_full    TO 'clinic_operator';
GRANT SELECT ON clinic.v_doctor_workload      TO 'clinic_operator';
GRANT EXECUTE ON PROCEDURE clinic.sp_create_appointment        TO 'clinic_operator';
GRANT EXECUTE ON PROCEDURE clinic.sp_change_appointment_status TO 'clinic_operator';
GRANT EXECUTE ON PROCEDURE clinic.sp_register_patient          TO 'clinic_operator';

GRANT ALL PRIVILEGES ON clinic.* TO 'clinic_admin';

CREATE USER IF NOT EXISTS 'app_readonly'@'localhost' IDENTIFIED BY 'ReadPass!23';
GRANT 'clinic_readonly' TO 'app_readonly'@'localhost';
SET DEFAULT ROLE ALL TO 'app_readonly'@'localhost';

CREATE USER IF NOT EXISTS 'app_operator'@'localhost' IDENTIFIED BY 'OpPass!23';
GRANT 'clinic_operator' TO 'app_operator'@'localhost';
SET DEFAULT ROLE ALL TO 'app_operator'@'localhost';

CREATE USER IF NOT EXISTS 'app_admin'@'localhost' IDENTIFIED BY 'AdminPass!23';
GRANT 'clinic_admin' TO 'app_admin'@'localhost';
SET DEFAULT ROLE ALL TO 'app_admin'@'localhost';

FLUSH PRIVILEGES;

-- =================================================================
-- ГОТОВО! Тестовые учётные записи приложения (пароль = test12345):
--   admin       — Администратор    (Звягенцев В.О.)
--   registrar1  — Регистратор      (Иванова А.П.)
--   petrov      — Врач (терапевт)  (Петров С.И.)
--   sidorova    — Врач (кардиолог) (Сидорова Е.В.)
--
-- Учётные записи MySQL Connector/NET для приложения:
--   app_operator / OpPass!23   — основная (для регистратор/врач)
--   app_admin    / AdminPass!23 — для административных операций
-- =================================================================
