-- ============================================================================
-- SCHEMA SUPABASE (POSTGRESQL + RLS) — ENE0066 PLANO INTERATIVO DE ESTUDOS
-- Universidade de Brasília (UnB) • Introdução aos Circuitos Elétricos
-- ============================================================================

create extension if not exists "uuid-ossp";

create table if not exists public.user_study_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  schema_version integer not null default 2,
  completed_exercises jsonb not null default '{}'::jsonb,
  diagnostic_results jsonb not null default '{}'::jsonb,
  mastery_states jsonb not null default '{}'::jsonb,
  schedule_state jsonb not null default '{}'::jsonb,
  grade_simulations jsonb not null default '{"p1": 2.5, "p2": 0.0, "p3": 6.5, "sub": 6.0}'::jsonb,
  study_notes jsonb not null default '{}'::jsonb,
  study_history jsonb not null default '[]'::jsonb,
  study_sessions jsonb not null default '{"totalMinutes": 0, "sessions": []}'::jsonb,
  mock_exams jsonb not null default '{}'::jsonb,
  ui_preferences jsonb not null default '{}'::jsonb,
  client_updated_at timestamptz not null default now(),
  server_updated_at timestamptz not null default now()
);

create table if not exists public.study_activity_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_type text not null check (activity_type in ('diagnostic_attempt', 'exercise_completed', 'schedule_recalculated', 'mock_exam', 'study_session', 'backup_migrated')),
  stage_id integer,
  topic_key text,
  score_pct numeric(5,2),
  mastery_assigned text,
  duration_minutes integer default 0,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_study_activity_logs_user_created
  on public.study_activity_logs (user_id, created_at desc);

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.server_updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_study_profiles_updated_at on public.user_study_profiles;
create trigger trg_user_study_profiles_updated_at
  before update on public.user_study_profiles
  for each row execute function public.handle_updated_at();

alter table public.user_study_profiles enable row level security;
alter table public.study_activity_logs enable row level security;

drop policy if exists "Users can view own study profile" on public.user_study_profiles;
create policy "Users can view own study profile"
  on public.user_study_profiles for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own study profile" on public.user_study_profiles;
create policy "Users can insert own study profile"
  on public.user_study_profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own study profile" on public.user_study_profiles;
create policy "Users can update own study profile"
  on public.user_study_profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own study profile" on public.user_study_profiles;
create policy "Users can delete own study profile"
  on public.user_study_profiles for delete
  using (auth.uid() = user_id);

drop policy if exists "Users can view own activity logs" on public.study_activity_logs;
create policy "Users can view own activity logs"
  on public.study_activity_logs for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own activity logs" on public.study_activity_logs;
create policy "Users can insert own activity logs"
  on public.study_activity_logs for insert
  with check (auth.uid() = user_id);

alter publication supabase_realtime add table public.user_study_profiles;