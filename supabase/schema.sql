-- ============================================================
-- VoxClass Database Schema
-- Run this in: Supabase Dashboard > SQL Editor > New Query
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ─── Tables ──────────────────────────────────────────────────

create table if not exists profiles (
  id         uuid references auth.users on delete cascade primary key,
  full_name  text not null,
  role       text not null check (role in ('lecturer', 'student')),
  avatar_url text,
  created_at timestamptz default now() not null
);

create table if not exists sessions (
  id          uuid default uuid_generate_v4() primary key,
  lecturer_id uuid references profiles(id) on delete cascade not null,
  title       text not null,
  subject     text,
  code        char(6) unique not null,
  status      text not null default 'active' check (status in ('active', 'ended')),
  created_at  timestamptz default now() not null,
  ended_at    timestamptz
);

create table if not exists reactions (
  id           uuid default uuid_generate_v4() primary key,
  session_id   uuid references sessions(id) on delete cascade not null,
  student_id   uuid references profiles(id) on delete set null,
  student_name text not null default 'Anonymous',
  type         text not null check (type in ('green', 'yellow', 'red')),
  created_at   timestamptz default now() not null
);

create table if not exists slides (
  id          uuid default uuid_generate_v4() primary key,
  session_id  uuid references sessions(id) on delete cascade not null,
  file_url    text not null,
  file_name   text not null,
  order_index int  default 0,
  created_at  timestamptz default now() not null
);

create table if not exists ai_questions (
  id            uuid default uuid_generate_v4() primary key,
  session_id    uuid references sessions(id) on delete cascade not null,
  slide_id      uuid references slides(id) on delete set null,
  question_text text not null,
  source_type   text not null check (source_type in ('slide', 'confused', 'manual')),
  is_pushed     boolean default false,
  created_at    timestamptz default now() not null
);

create table if not exists question_responses (
  id            uuid default uuid_generate_v4() primary key,
  question_id   uuid references ai_questions(id) on delete cascade not null,
  student_id    uuid references profiles(id) on delete set null,
  student_name  text not null default 'Anonymous',
  response_text text not null,
  created_at    timestamptz default now() not null
);

create table if not exists polish_logs (
  id          uuid default uuid_generate_v4() primary key,
  user_id     uuid references profiles(id) on delete cascade not null,
  input_text  text not null,
  output_text text not null,
  mode        text not null check (mode in ('soften', 'strengthen', 'academic', 'simplify')),
  created_at  timestamptz default now() not null
);

-- ─── Trigger: auto-create profile on signup ──────────────────

create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    coalesce(new.raw_user_meta_data->>'role', 'student')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ─── Row Level Security ───────────────────────────────────────

alter table profiles          enable row level security;
alter table sessions          enable row level security;
alter table reactions         enable row level security;
alter table slides            enable row level security;
alter table ai_questions      enable row level security;
alter table question_responses enable row level security;
alter table polish_logs       enable row level security;

-- Profiles
create policy "profiles_select" on profiles for select using (true);
create policy "profiles_update" on profiles for update using (auth.uid() = id);

-- Sessions
create policy "sessions_select" on sessions for select using (true);
create policy "sessions_insert" on sessions for insert with check (auth.uid() = lecturer_id);
create policy "sessions_update" on sessions for update using (auth.uid() = lecturer_id);

-- Reactions
create policy "reactions_select" on reactions for select using (true);
create policy "reactions_insert" on reactions for insert with check (auth.uid() is not null);

-- Slides
create policy "slides_select" on slides for select using (true);
create policy "slides_insert" on slides for insert with check (
  auth.uid() = (select lecturer_id from sessions where id = session_id)
);

-- AI Questions
create policy "questions_select" on ai_questions for select using (true);
create policy "questions_insert" on ai_questions for insert with check (
  auth.uid() = (select lecturer_id from sessions where id = session_id)
);
create policy "questions_update" on ai_questions for update using (
  auth.uid() = (select lecturer_id from sessions where id = session_id)
);

-- Question responses
create policy "responses_select" on question_responses for select using (true);
create policy "responses_insert" on question_responses for insert with check (auth.uid() is not null);

-- Polish logs
create policy "polish_select" on polish_logs for select using (auth.uid() = user_id);
create policy "polish_insert" on polish_logs for insert with check (auth.uid() = user_id);

-- ─── Storage bucket ───────────────────────────────────────────
-- Run separately in Supabase Dashboard > Storage > New Bucket
-- Bucket name: slides
-- Public: true

-- ─── Enable Realtime ─────────────────────────────────────────
-- Supabase Dashboard > Database > Replication
-- Toggle ON for tables: reactions, ai_questions, slides
