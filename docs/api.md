# API Contract

Base path: `/api/v1`. Authenticated endpoints require `Authorization: Bearer <access_token>`. JSON validation errors use FastAPI's standard `422` response. `GET /docs` and `/openapi.json` provide interactive and machine-readable OpenAPI descriptions.

Registration and login trim and lowercase email addresses before lookup/storage. Passwords must be 8-128 characters and are stored with Argon2 hashing; plaintext passwords are never returned. PostgreSQL enforces case-insensitive email uniqueness, so concurrent duplicate registrations cannot create duplicate accounts.

| Method | Path | Request / result |
|---|---|---|
| POST | `/auth/register` | `{name,email,password,age?,height_cm?,weight_kg?,gender?}` -> user (`201`); invalid data (`422`); duplicate normalized email (`409`) |
| POST | `/auth/login` | `{email,password}` -> `{access_token,token_type}`; incorrect credentials (`401`) |
| GET | `/auth/profile` | -> authenticated user |
| PUT | `/auth/profile` | `{age,height_cm,weight_kg}` -> updated authenticated user; invalid values (`422`) |
| POST | `/activity/predict` | `{window_start,sample_rate_hz,samples:[{timestamp,acc_x,acc_y,acc_z,gyro_x?,gyro_y?,gyro_z?}]}` -> prediction; `503` if model unavailable |
| GET | `/activity/current` | -> latest activity, confidence, and prediction timestamp; null activity if none |
| GET | `/activity/history?limit=&offset=` | -> latest activity sessions |
| GET | `/activity/today` | -> date, per-activity duration seconds, logs |
| POST | `/steps/update` | `{log_date,steps,distance_km,calories_burned}` -> upserted daily total |
| GET | `/steps/today` | -> today's totals, zero values when empty |
| GET | `/steps/history?start=&end=` | -> daily totals in date range |
| GET | `/analytics/daily?date=` | -> daily aggregate |
| GET | `/analytics/weekly?week_start=` | -> seven daily values and totals |
| GET | `/analytics/monthly?year=&month=` | -> daily values and monthly totals |
| POST | `/goals` | `{daily_step_goal,weekly_running_goal,monthly_distance_goal}` -> created goals (`201`) |
| GET | `/goals` | -> current goals (defaults are created on first read) |
| PUT | `/goals` | same goal fields -> replaced values |

Step updates replace the user's daily totals, so clients submit absolute daily values and retries are idempotent. On first pedometer synchronization, the app reconciles the device's since-UTC-midnight count against the server total; later watch updates add only the new sensor delta. API date values use UTC calendar days.