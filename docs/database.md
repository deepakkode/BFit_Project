# Database Design

All primary keys are UUID values stored as strings for portability; event timestamps use timezone-aware columns and are written in UTC. Foreign keys cascade user-owned data on account deletion. PostgreSQL is the system of record.

```mermaid
erDiagram
  USERS ||--o{ ACTIVITY_LOGS : records
  USERS ||--o{ STEP_LOGS : records
  USERS ||--o{ DAILY_SUMMARY : aggregates
  USERS ||--o{ MODEL_PREDICTIONS : receives
  USERS ||--o| USER_GOALS : sets
  MODEL_VERSIONS ||--o{ MODEL_PREDICTIONS : serves
  USERS { string id PK; string name; string email UK; string password_hash; int age; float height_cm; float weight_kg; string gender; string timezone; timestamptz created_at; timestamptz updated_at }
  ACTIVITY_LOGS { string id PK; string user_id FK; string activity; float confidence_score; timestamptz start_time; timestamptz end_time; int duration_seconds; timestamptz created_at }
  STEP_LOGS { string id PK; string user_id FK; date log_date; int steps; float distance_km; float calories_burned; timestamptz created_at }
  DAILY_SUMMARY { string id PK; string user_id FK; date summary_date; int walking_minutes; int running_minutes; int sitting_minutes; int standing_minutes; int total_steps; float total_distance; float total_calories }
  MODEL_PREDICTIONS { string id PK; string user_id FK; string model_version_id FK; string model_name; string predicted_activity; float confidence_score; timestamptz prediction_timestamp }
  MODEL_VERSIONS { string id PK; string model_name; string version; string artifact_uri; json metrics; timestamptz trained_at }
  USER_GOALS { string id PK; string user_id FK; int daily_step_goal; int weekly_running_goal; float monthly_distance_goal; timestamptz created_at }
```

Constraints enforce the four supported activities, confidence in `[0,1]`, nonnegative durations/counts/metrics, chronological activity intervals, one step record per user/day, one summary per user/day, one active goal record per user, and one row per model/version. Indexes support activity history, prediction history, and step date lookups. Alembic owns schema changes; never use `Base.metadata.create_all()` in application startup.

Daily summaries are derived and can be rebuilt from activity and step records. The app currently uses UTC calendar dates; per-user timezone aggregation is a production follow-up before supporting users across time zones.