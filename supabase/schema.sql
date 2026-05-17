-- ─────────────────────────────────────────────────────────────────────────────
-- VoxClass — Supabase Schema
-- Run this entire file in the Supabase SQL Editor for a fresh project.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Profiles ──────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id        uuid primary key references auth.users on delete cascade,
  full_name text not null,
  role      text not null check (role in ('lecturer', 'student')),
  created_at timestamptz default now()
);

-- ── Sessions ──────────────────────────────────────────────────────────────────
create table if not exists public.sessions (
  id               uuid primary key default gen_random_uuid(),
  lecturer_id      uuid references public.profiles(id) on delete cascade,
  title            text not null,
  subject          text,
  code             text not null unique,
  status           text default 'active' check (status in ('active', 'ended')),
  current_slide_id uuid,
  pointer_x        float,
  pointer_y        float,
  pointer_visible  boolean default false,
  created_at       timestamptz default now(),
  ended_at         timestamptz
);

-- ── Reactions ─────────────────────────────────────────────────────────────────
create table if not exists public.reactions (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid references public.sessions(id) on delete cascade,
  student_id   uuid references auth.users(id) on delete set null,
  student_name text not null,
  type         text not null check (type in ('green', 'yellow', 'red')),
  created_at   timestamptz default now()
);

-- ── Slides ────────────────────────────────────────────────────────────────────
create table if not exists public.slides (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid references public.sessions(id) on delete cascade,
  file_url      text not null,
  file_name     text not null,
  order_index   int default 0,
  speaker_notes text,
  created_at    timestamptz default now()
);

-- ── AI Questions ──────────────────────────────────────────────────────────────
create table if not exists public.ai_questions (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid references public.sessions(id) on delete cascade,
  slide_id      uuid references public.slides(id) on delete set null,
  question_text text not null,
  source_type   text not null,
  is_pushed     boolean default false,
  created_at    timestamptz default now()
);

-- ── Question Responses ────────────────────────────────────────────────────────
create table if not exists public.question_responses (
  id            uuid primary key default gen_random_uuid(),
  question_id   uuid references public.ai_questions(id) on delete cascade,
  student_id    uuid references auth.users(id) on delete set null,
  student_name  text not null,
  response_text text not null,
  created_at    timestamptz default now()
);

-- ── Anonymous Questions ───────────────────────────────────────────────────────
create table if not exists public.anonymous_questions (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid references public.sessions(id) on delete cascade,
  question_text text not null,
  created_at    timestamptz default now()
);

-- ── Polish Logs ───────────────────────────────────────────────────────────────
create table if not exists public.polish_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete set null,
  input_text  text,
  output_text text,
  mode        text,
  created_at  timestamptz default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.profiles            enable row level security;
alter table public.sessions            enable row level security;
alter table public.reactions           enable row level security;
alter table public.slides              enable row level security;
alter table public.ai_questions        enable row level security;
alter table public.question_responses  enable row level security;
alter table public.anonymous_questions enable row level security;
alter table public.polish_logs         enable row level security;

-- profiles
create policy "Users manage own profile"
  on public.profiles for all using (auth.uid() = id);

-- sessions (open read so students can join by code)
create policy "Anyone can read sessions"
  on public.sessions for select using (true);
create policy "Lecturers create sessions"
  on public.sessions for insert with check (auth.uid() = lecturer_id);
create policy "Lecturers update own sessions"
  on public.sessions for update using (auth.uid() = lecturer_id);

-- reactions
create policy "Anyone can read reactions"
  on public.reactions for select using (true);
create policy "Anyone can insert reactions"
  on public.reactions for insert with check (true);

-- slides
create policy "Anyone can read slides"
  on public.slides for select using (true);
create policy "Anyone can insert slides"
  on public.slides for insert with check (true);
create policy "Anyone can update slides"
  on public.slides for update using (true);
create policy "Anyone can delete slides"
  on public.slides for delete using (true);

-- ai_questions
create policy "Anyone can read questions"
  on public.ai_questions for select using (true);
create policy "Anyone can insert questions"
  on public.ai_questions for insert with check (true);
create policy "Anyone can update questions"
  on public.ai_questions for update using (true);

-- question_responses
create policy "Anyone can read responses"
  on public.question_responses for select using (true);
create policy "Anyone can insert responses"
  on public.question_responses for insert with check (true);

-- anonymous_questions
create policy "Anyone can read anon questions"
  on public.anonymous_questions for select using (true);
create policy "Anyone can insert anon questions"
  on public.anonymous_questions for insert with check (true);

-- polish_logs
create policy "Users manage own polish logs"
  on public.polish_logs for all using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Auto-create profile on signup
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    coalesce(new.raw_user_meta_data->>'role', 'student')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- After running this SQL:
-- 1. Go to Table Editor → reactions / ai_questions / slides / sessions
--    → enable Realtime on each table
-- 2. Go to Storage → New bucket → Name: slides → toggle Public ON
-- ─────────────────────────────────────────────────────────────────────────────
