# Информационная система «Поликлиника»

Производственная практика по **ПМ.05 «Проектирование и разработка информационных систем»**

**Студент:** Звягенцев Владислав Олегович
**Группа:** ДКИП-403
**Год:** 2026

---

## О проекте

Десктопное приложение для автоматизации работы регистратуры и врачей городской поликлиники «МедЦентр». Решает задачи учёта пациентов, ведения расписания приёмов, фиксации диагнозов и истории обращений.

### Ролевая модель

В системе три типа пользователей с разным набором прав:

- **Администратор** — управляет справочниками (специализациями, врачами, пользователями), имеет полный доступ к данным.
- **Регистратор** — регистрирует новых пациентов, создаёт записи на приём, отменяет записи, просматривает расписание врачей.
- **Врач** — видит свой список приёмов, открывает приём, вносит диагноз и рекомендации, завершает приём.

---

## Стек технологий

| Компонент | Технология |
|-----------|------------|
| СУБД | MySQL 8 (XAMPP, phpMyAdmin) |
| Платформа | .NET Framework 4.7.2 |
| Язык | C# |
| GUI | Windows Forms |
| Доступ к БД | MySql.Data (MySQL Connector/NET) 8.0.33 |
| Хэширование паролей | SHA-256 + соль (System.Security.Cryptography) |

---

## Версии (Releases)

| Версия | Описание | Ссылка |
|--------|----------|--------|
| v1.0 | DDL-скрипт + тестовые данные (8 таблиц, индексы, INSERT) | [v1.0](https://github.com/Zyrox1231345345/PM-0.5-MED/releases/tag/v1.0) |
| v2.0 | CRUD-операции в C# WinForms-приложении | [v2.0](https://github.com/Zyrox1231345345/PM-0.5-MED/releases/tag/v2.0) |
| v3.0 | Представления (VIEW) и хранимые процедуры | [v3.0](https://github.com/Zyrox1231345345/PM-0.5-MED/releases/tag/v3.0) |
| v4.0 | Триггеры и ролевая модель безопасности MySQL | [v4.0](https://github.com/Zyrox1231345345/PM-0.5-MED/releases/tag/v4.0) |
| **v5.0** | **Финальная версия — всё вместе + хэширование паролей SHA-256 + соль** | [v5.0](https://github.com/Zyrox1231345345/PM-0.5-MED/releases/tag/v5.0) |

Полный SQL-дамп последней версии: [`clinic_full.sql`](https://github.com/Zyrox1231345345/PM-0.5-MED/blob/main/clinic_full.sql)

---

## Структура репозитория

```
PM-0.5-MED/
├── ClinicApp/                       — Проект C# WinForms
│   ├── ClinicApp.csproj             — Файл проекта (SDK-style)
│   ├── App.config                   — Строка подключения к MySQL
│   ├── Program.cs                   — Точка входа
│   ├── AppSession.cs                — Контекст сеанса (роль, ID юзера)
│   ├── Data/
│   │   └── DBConnection.cs          — Получение MySqlConnection
│   ├── Security/
│   │   └── PasswordHelper.cs        — SHA-256 + соль
│   └── Forms/
│       ├── LoginForm.cs             — Вход в систему
│       ├── MainForm.cs              — Главное окно с меню
│       ├── AppointmentsForm.cs      — Список приёмов (READ через VIEW)
│       ├── NewAppointmentForm.cs    — Создание приёма (CREATE через процедуру)
│       ├── AppointmentDetailForm.cs — Открытие приёма + ввод диагноза
│       ├── PatientsForm.cs          — Пациенты + регистрация (CRUD)
│       ├── AdminForms.cs            — Doctors / Specializations / Users / UserEdit
│       └── ReportsForm.cs           — Отчёт по загрузке врачей
├── clinic_full.sql                  — Полный дамп БД (схема + данные + объекты)
└── README.md                        — Этот файл
```

---

## Что реализовано (по этапам практики)

### Этап 1. Проектирование базы данных

Спроектирована реляционная БД из **8 таблиц**, нормализованных до 3НФ:

- `roles` — справочник ролей (admin / registrar / doctor)
- `users` — учётные записи (с полями `password_salt` и `password_hash`)
- `specializations` — справочник специализаций врачей
- `doctors` — врачи (1:1 с `users` через `UNIQUE user_id`)
- `patients` — пациенты (с уникальным номером полиса ОМС)
- `appointments` — записи на приём (статусы: scheduled / in_progress / completed / cancelled)
- `diagnoses` — диагнозы по приёму (CASCADE от `appointments`)
- `appointment_history` — журнал изменений статусов (CASCADE от `appointments`)

**Типы связей:** 1:1 (пользователь — врач), 1:N (роль — пользователи, врач — приёмы и т.д.), 1:N CASCADE (приём — диагнозы, приём — история).

Используется движок **InnoDB** для поддержки внешних ключей, кодировка **utf8mb4** для корректной работы с кириллицей. Добавлены индексы на FK-поля для ускорения JOIN.

### Этап 2. Объекты БД

**2 представления (VIEW):**
- `v_appointments_full` — JOIN из 5 таблиц, основной источник данных для списка приёмов в DataGridView.
- `v_doctor_workload` — агрегат с условным `COUNT(CASE WHEN ...)` и LEFT JOIN, показывает загрузку каждого врача по статусам.

**4 хранимые процедуры:**
- `sp_create_appointment` — создание записи с проверкой занятости врача (`SIGNAL SQLSTATE '45000'` при конфликте), возврат ID через `OUT`-параметр.
- `sp_change_appointment_status` — смена статуса приёма с журналированием в `appointment_history`.
- `sp_register_patient` — регистрация пациента с проверкой уникальности полиса.
- `sp_register_user` — регистрация пользователя приложения (соль и хэш приходят уже готовые из C#).

**2 триггера:**
- `trg_log_status_change` (`AFTER UPDATE`) — аудит смены статуса в `appointment_history`.
- `trg_update_timestamp` (`BEFORE UPDATE`) — автоматическое заполнение `updated_at`.

### Этап 3. Безопасность

**Уровень СУБД** — три групповые роли MySQL по принципу минимальных привилегий:

| Роль СУБД | Привилегии |
|-----------|------------|
| `clinic_readonly` | SELECT на все таблицы и VIEW |
| `clinic_operator` | SELECT/INSERT/UPDATE на рабочие таблицы, EXECUTE на процедуры |
| `clinic_admin` | ALL PRIVILEGES на БД |

Под эти роли созданы три учётные записи MySQL (`app_readonly`, `app_operator`, `app_admin`).

**Уровень приложения** — хэширование паролей по схеме SHA-256 + уникальная соль (16 байт через `RandomNumberGenerator`). Класс `PasswordHelper` инкапсулирует:
- `GenerateSalt()` — генерация 32-символьной hex-строки соли,
- `HashPassword(pwd, salt)` — вычисление SHA-256 от `salt + password`,
- `VerifyPassword(input, salt, storedHash)` — сравнение хэшей.

В таблице `users` пароли в открытом виде **не хранятся** — только соль и хэш.

### Этап 4. CRUD и JOIN

**Все четыре CRUD-операции** для основной сущности `appointments`:
- **READ** — `MySqlDataAdapter` из `v_appointments_full` с фильтрацией по статусу.
- **CREATE** — параметризованный вызов `sp_create_appointment` с получением ID через `OUT`.
- **UPDATE** — `sp_change_appointment_status` через `CommandType.StoredProcedure`.
- **DELETE** — параметризованный `DELETE` с каскадным удалением диагнозов и истории.

**5 видов JOIN-запросов** в отчётах:
- INNER JOIN (2 таблицы и 5 таблиц)
- LEFT JOIN с `WHERE IS NULL` (приёмы без диагноза)
- RIGHT JOIN (все специализации, включая пустые)
- GROUP BY + HAVING (загрузка врачей с фильтром по числу приёмов)

**11 форм WinForms** с разграничением доступа по ролям через `AppSession.IsAdmin` / `IsRegistrar` / `IsDoctor`. Все запросы — параметризованные, что защищает от SQL-инъекций. Обработка ошибок процедур (`SIGNAL`) через `catch (MySqlException)`.

---

## Установка и запуск

### 1. Развёртывание БД

Запусти **XAMPP** → включи **Apache** и **MySQL**.

Открой phpMyAdmin (http://localhost/phpmyadmin) и импортируй `clinic_full.sql`:

**Вариант А — через командную строку (надёжнее):**
```bash
cd C:\xampp\mysql\bin
mysql.exe -u root -p < путь\к\clinic_full.sql
```

**Вариант Б — через phpMyAdmin:**
1. Создай БД `clinic` (если её нет)
2. Открой вкладку **SQL**
3. Скопируй содержимое `clinic_full.sql` в поле и нажми **Вперёд**

После импорта в БД `clinic` будут все таблицы, VIEW, процедуры, триггеры и тестовые данные.

### 2. Запуск приложения

1. Открой `ClinicApp/ClinicApp.csproj` в **Visual Studio 2019/2022**.
2. NuGet подтянет `MySql.Data` автоматически. Если нет — установи вручную:
   `Tools → NuGet Package Manager → Manage Packages for Solution → MySql.Data 8.0.33`
3. Если порт MySQL отличается от 3306 — поправь `App.config`:
   ```xml
   <add name="ClinicDB"
        connectionString="server=127.0.0.1;port=3306;database=clinic;user=root;password=;charset=utf8mb4;"
        providerName="MySql.Data.MySqlClient" />
   ```
4. **F5** — приложение запустится.

### 3. Тестовые учётные записи

| Логин | Пароль | Роль |
|-------|--------|------|
| `admin` | `test12345` | Администратор |
| `registrar1` | `test12345` | Регистратор |
| `petrov` | `test12345` | Врач (терапевт) |
| `sidorova` | `test12345` | Врач (кардиолог) |

---

## Возможные проблемы

| Симптом | Решение |
|---------|---------|
| `Authentication method 'caching_sha2_password' not supported` | Обнови MySQL Connector до 8.0+, либо: `ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';` |
| `Unable to connect to any of the specified MySQL hosts` | Запусти MySQL в XAMPP, проверь порт в `App.config` (3306 / 3307) |
| `Unknown database 'clinic'` | Импорт SQL не прошёл — повторить через командную строку |
| `Illegal mix of collations` | `ALTER DATABASE clinic COLLATE utf8mb4_unicode_ci;` для всех таблиц |
| Ошибка `SET DEFAULT ROLE` при импорте | Не критично — это для MySQL 8+, MariaDB её игнорирует. Все остальные объекты создаются нормально. |

---

## Лицензия и автор

Учебный проект, выполнен в рамках производственной практики ПМ.05.
**Автор:** Звягенцев Владислав Олегович, гр. ДКИП-403, 2026 г.
