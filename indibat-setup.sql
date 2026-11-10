-- =====================================================================
--  منصة «انضباط»: الحضور والسلوك للمدرسة كلها (نفس قاعدة بيانات «أثر»)
--  آمن للتشغيل أكثر من مرة.
-- =====================================================================
create table if not exists public.app_settings (key text primary key, value jsonb not null default '{}', updated_at timestamptz not null default now());
alter table public.app_settings enable row level security;
drop policy if exists app_read on public.app_settings;
drop policy if exists app_write on public.app_settings;
create policy app_read on public.app_settings for select to authenticated using (public.is_staff());
create policy app_write on public.app_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

create table if not exists public.sch_students (
  id text primary key default gen_random_uuid()::text,
  school_no text not null unique,
  name text not null,
  grade text, section text, guardian text, phone text, phone2 text, notes text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.sch_registers (
  "date" date not null, grade text not null, section text not null,
  taken_by uuid default auth.uid(), taken_by_name text, taken_at timestamptz not null default now(),
  primary key ("date", grade, section)
);
create table if not exists public.sch_attendance (
  id text primary key default gen_random_uuid()::text,
  student_id text not null references public.sch_students(id) on delete cascade,
  "date" date not null,
  status text not null check (status in ('absent','late','excused','early')),
  minutes int, reason text, notified boolean not null default false,
  recorded_by uuid default auth.uid(), created_at timestamptz not null default now(),
  unique (student_id, "date")
);
create index if not exists sch_att_date_idx on public.sch_attendance("date");
-- تحديث: خانة «الإجراء المتخذ» مع الطالب في الغياب والتأخير
alter table public.sch_attendance add column if not exists action text;
-- وقت الوصول للتأخير الصباحي (يُحسب التأخير من بعد 7:15)
alter table public.sch_attendance add column if not exists arrive_at text;
create table if not exists public.sch_behavior (
  id text primary key default gen_random_uuid()::text,
  student_id text not null references public.sch_students(id) on delete cascade,
  "date" date not null,
  kind text not null check (kind in ('positive','violation')),
  degree int, category text, description text, action text, points numeric not null default 0,
  recorded_by uuid default auth.uid(), recorded_by_name text, notified boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists sch_beh_date_idx on public.sch_behavior("date");
create index if not exists sch_beh_student_idx on public.sch_behavior(student_id);

do $$
declare t text;
begin
  foreach t in array array['sch_students','sch_registers','sch_attendance','sch_behavior'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists staff_all on public.%I', t);
    execute format('create policy staff_all on public.%I for all to authenticated using (public.is_staff()) with check (public.is_staff())', t);
  end loop;
end $$;

-- =====================================================================
--  التسجيل بالبريد الوزاري فقط + موافقة المسؤول
--  (يطبَّق على أي حساب جديد في المشروع، ومنها حسابات «أثر»)
--  لتعديل النطاقات المسموحة: غيّر القائمة في الدالة أدناه وفي ATHAR_CONFIG.domains
-- =====================================================================
create or replace function public.enforce_ministry_email() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if lower(split_part(coalesce(new.email, ''), '@', 2)) not in ('moe.sch.ae') then
    raise exception 'يُسمح بالتسجيل بالبريد الوزاري فقط' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists enforce_ministry_email on auth.users;
create trigger enforce_ministry_email before insert on auth.users
  for each row execute function public.enforce_ministry_email();

-- يسمح لمسؤول النظام برفض الطلبات (حذفها من قائمة المستخدمين)
drop policy if exists staff_admin_delete on public.staff;
create policy staff_admin_delete on public.staff for delete to authenticated using (public.is_admin());

-- الصفة الوظيفية للمستخدم (المديرة، رئيس وحدة شؤون الطلبة، المرشد الأكاديمي والمهني…)
alter table public.staff add column if not exists job text;

-- إشعارات المستخدمين (الموافقة على الحساب، التعيين بصفة وظيفية…)
create table if not exists public.sch_notices (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null,
  title text, body text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.sch_notices enable row level security;
drop policy if exists notices_admin on public.sch_notices;
create policy notices_admin on public.sch_notices for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists notices_self_read on public.sch_notices;
create policy notices_self_read on public.sch_notices for select to authenticated using (user_id = auth.uid());
drop policy if exists notices_self_update on public.sch_notices;
create policy notices_self_update on public.sch_notices for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- دراسة الحالة (ملف لكل طالب: أصحاب الهمم، ارتباط الإعاقة بالسلوك، خطة العلاج، التوصيات)
create table if not exists public.sch_cases (
  student_id text primary key references public.sch_students(id) on delete cascade,
  data jsonb not null default '{}',
  updated_by_name text,
  updated_at timestamptz not null default now()
);
alter table public.sch_cases enable row level security;
drop policy if exists staff_all on public.sch_cases;
create policy staff_all on public.sch_cases for all to authenticated using (public.is_staff()) with check (public.is_staff());
