-- Northern Star production schema. Apply to a new Supabase project.
create extension if not exists pgcrypto;

create type public.staff_role as enum ('participant','field_officer','case_worker','supervisor','me_officer','finance_officer','admin');
create type public.bucket_level as enum ('L0','L1','L2','L3');
create type public.application_status as enum ('draft','submitted','under_review','needs_information','shortlisted','enrolled','declined','withdrawn');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.staff_role not null default 'participant',
  phone text,
  preferred_language text not null default 'en',
  state_name text,
  lga text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.participants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  participant_code text unique not null default ('NS-' || upper(substr(encode(gen_random_bytes(5),'hex'),1,8))),
  full_name text not null,
  date_of_birth date,
  phone text,
  email text,
  gender text,
  state_name text not null,
  lga text not null,
  community text,
  nysc_status text,
  nysc_state_code text,
  education_level text,
  livelihood_status text,
  current_level public.bucket_level,
  assigned_officer uuid references public.profiles(id) on delete set null,
  assigned_case_worker uuid references public.profiles(id) on delete set null,
  consent_status text not null default 'pending' check (consent_status in ('pending','granted','withdrawn')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  public_ref text unique not null default ('APP-' || upper(substr(encode(gen_random_bytes(5),'hex'),1,8))),
  participant_id uuid not null references public.participants(id) on delete cascade,
  program_name text not null,
  status public.application_status not null default 'draft',
  submitted_at timestamptz,
  reviewer_id uuid references public.profiles(id) on delete set null,
  review_note text,
  source text not null default 'portal',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  assessed_by uuid references public.profiles(id) on delete set null,
  assessment_type text not null default 'needs_check',
  recommended_level public.bucket_level,
  answers jsonb not null default '{}'::jsonb,
  summary text,
  completed_at timestamptz not null default now()
);

create table public.surveys (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  stage text not null check (stage in ('baseline','midline','endline','custom')),
  schema jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.survey_responses (
  id uuid primary key default gen_random_uuid(),
  survey_id uuid not null references public.surveys(id) on delete cascade,
  participant_id uuid not null references public.participants(id) on delete cascade,
  collected_by uuid references public.profiles(id) on delete set null,
  answers jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now()
);

create table public.programs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  target_level public.bucket_level,
  state_name text,
  capacity integer check (capacity is null or capacity >= 0),
  start_date date,
  end_date date,
  status text not null default 'planning' check (status in ('planning','open','active','completed','paused')),
  created_at timestamptz not null default now()
);
create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  program_id uuid not null references public.programs(id) on delete restrict,
  status text not null default 'active' check (status in ('active','completed','withdrawn','on_hold')),
  enrolled_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(participant_id, program_id)
);

create table public.case_notes (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete restrict,
  note text not null,
  sensitivity text not null default 'standard' check (sensitivity in ('standard','restricted')),
  created_at timestamptz not null default now()
);
create table public.participant_documents (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  file_name text not null,
  category text not null,
  storage_path text not null,
  consent_confirmed boolean not null default false,
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  sensitivity text not null default 'standard' check (sensitivity in ('standard','restricted')),
  created_at timestamptz not null default now()
);
create table public.participant_feedback (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  feedback_type text not null check (feedback_type in ('programme','service','complaint','suggestion','wellbeing_check')),
  body text not null,
  resolution_status text not null default 'open' check (resolution_status in ('open','in_review','resolved','referred')),
  submitted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.participant_flags (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  flag_type text not null,
  summary text not null,
  sensitivity text not null default 'restricted' check (sensitivity in ('standard','restricted')),
  status text not null default 'open' check (status in ('open','in_review','resolved')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  resolved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.progress_milestones (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'upcoming' check (status in ('upcoming','in_progress','completed','blocked')),
  due_date date,
  completed_at timestamptz,
  recorded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  program_id uuid references public.programs(id) on delete set null,
  session_name text not null,
  attended boolean not null,
  session_date date not null default current_date,
  recorded_by uuid references public.profiles(id) on delete set null
);
create table public.income_snapshots (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  monthly_income_ngn numeric(14,2) check (monthly_income_ngn is null or monthly_income_ngn >= 0),
  business_status text,
  captured_at date not null default current_date,
  captured_by uuid references public.profiles(id) on delete set null,
  notes text
);
create table public.level_transitions (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  from_level public.bucket_level,
  to_level public.bucket_level not null,
  reason text not null,
  approved_by uuid references public.profiles(id) on delete set null,
  transitioned_at timestamptz not null default now()
);

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  partner_type text not null,
  contact_name text,
  contact_email text,
  contact_phone text,
  state_name text,
  lga text,
  services text[] not null default '{}',
  status text not null default 'prospect' check (status in ('prospect','active','paused','closed')),
  notes text,
  created_at timestamptz not null default now()
);
create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  partner_id uuid references public.partners(id) on delete set null,
  service text not null,
  status text not null default 'created' check (status in ('created','assigned','accepted','in_progress','completed','declined','cancelled')),
  referred_by uuid references public.profiles(id) on delete set null,
  outcome text,
  referred_at timestamptz not null default now(),
  completed_at timestamptz
);
create table public.outreach_events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  state_name text not null,
  lga text,
  community text,
  event_date date not null,
  target_reach integer not null default 0 check (target_reach >= 0),
  people_reached integer not null default 0 check (people_reached >= 0),
  registrations integer not null default 0 check (registrations >= 0),
  assessments integer not null default 0 check (assessments >= 0),
  enrollments integer not null default 0 check (enrollments >= 0),
  follow_up_required integer not null default 0 check (follow_up_required >= 0),
  team_notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.impact_stories (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid references public.participants(id) on delete set null,
  title text not null,
  story_body text not null,
  format text not null default 'case_study' check (format in ('testimonial','case_study','photo_story','video_story')),
  consent_confirmed boolean not null default false,
  publication_status text not null default 'draft' check (publication_status in ('draft','review','approved','published','withdrawn')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.finance_entries (
  id uuid primary key default gen_random_uuid(),
  entry_type text not null check (entry_type in ('budget','disbursement','expense')),
  program_id uuid references public.programs(id) on delete set null,
  participant_id uuid references public.participants(id) on delete set null,
  amount_ngn numeric(14,2) not null check (amount_ngn >= 0),
  description text not null,
  reference text,
  status text not null default 'pending' check (status in ('pending','approved','paid','rejected','reconciled')),
  entered_by uuid references public.profiles(id) on delete set null,
  approved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  channel text not null default 'portal' check (channel in ('portal','sms','email','whatsapp')),
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  participant_id uuid references public.participants(id) on delete set null,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index participants_geo_idx on public.participants(state_name,lga);
create index participants_officer_idx on public.participants(assigned_officer);
create index applications_status_idx on public.applications(status,created_at desc);
create index assessments_participant_idx on public.assessments(participant_id,completed_at desc);
create index referrals_status_idx on public.referrals(status,referred_at desc);
create index activity_events_created_idx on public.activity_events(created_at desc);

create or replace function public.current_role() returns public.staff_role
language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(public.current_role() <> 'participant', false) $$;
create or replace function public.is_admin_or_supervisor() returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(public.current_role() in ('admin','supervisor'), false) $$;
create or replace function public.is_care_staff() returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(public.current_role() in ('admin','supervisor','case_worker','field_officer','me_officer'), false) $$;
create or replace function public.can_access_participant(target_participant uuid) returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(
  public.current_role() in ('admin','supervisor','me_officer') or exists(
    select 1 from public.participants p where p.id=target_participant and
      ((public.current_role()='field_officer' and p.assigned_officer=auth.uid()) or
       (public.current_role()='case_worker' and (p.assigned_case_worker=auth.uid() or p.assigned_officer=auth.uid())))
  ), false) $$;

alter table public.profiles enable row level security;
alter table public.participants enable row level security;
alter table public.applications enable row level security;
alter table public.assessments enable row level security;
alter table public.surveys enable row level security;
alter table public.survey_responses enable row level security;
alter table public.programs enable row level security;
alter table public.enrollments enable row level security;
alter table public.case_notes enable row level security;
alter table public.participant_documents enable row level security;
alter table public.participant_feedback enable row level security;
alter table public.participant_flags enable row level security;
alter table public.progress_milestones enable row level security;
alter table public.attendance enable row level security;
alter table public.income_snapshots enable row level security;
alter table public.level_transitions enable row level security;
alter table public.partners enable row level security;
alter table public.referrals enable row level security;
alter table public.outreach_events enable row level security;
alter table public.impact_stories enable row level security;
alter table public.finance_entries enable row level security;
alter table public.messages enable row level security;
alter table public.activity_events enable row level security;
alter table public.audit_logs enable row level security;

create policy "profile self or staff read" on public.profiles for select using (id = auth.uid() or public.is_staff());
create policy "profile self update" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "profile self create" on public.profiles for insert with check (id = auth.uid());
create policy "participant owner or assigned staff read" on public.participants for select using (user_id = auth.uid() or public.current_role() in ('admin','supervisor','me_officer') or (public.current_role()='field_officer' and assigned_officer=auth.uid()) or (public.current_role()='case_worker' and (assigned_case_worker=auth.uid() or assigned_officer=auth.uid())));
create policy "participant self create" on public.participants for insert with check ((user_id = auth.uid() and public.current_role()='participant' and current_level is null and assigned_officer is null and assigned_case_worker is null) or public.current_role() in ('admin','supervisor','case_worker','field_officer'));
create policy "participant assigned staff update" on public.participants for update using (public.current_role() in ('admin','supervisor','me_officer') or (public.current_role()='field_officer' and assigned_officer=auth.uid()) or (public.current_role()='case_worker' and (assigned_case_worker=auth.uid() or assigned_officer=auth.uid()))) with check (public.current_role() in ('admin','supervisor','me_officer') or (public.current_role()='field_officer' and assigned_officer=auth.uid()) or (public.current_role()='case_worker' and (assigned_case_worker=auth.uid() or assigned_officer=auth.uid())));
create policy "application owner or assigned staff read" on public.applications for select using (exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) or public.can_access_participant(participant_id));
create policy "application owner create or care staff" on public.applications for insert with check ((exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) and status in ('draft','submitted') and reviewer_id is null and review_note is null) or public.is_care_staff());
create policy "application assigned staff update" on public.applications for update using (public.can_access_participant(participant_id)) with check (public.can_access_participant(participant_id));
create policy "assessment owner or assigned staff read" on public.assessments for select using (exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) or public.can_access_participant(participant_id));
create policy "assessment owner or assigned staff create" on public.assessments for insert with check (exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) or public.can_access_participant(participant_id));
create policy "surveys care staff manage" on public.surveys for all using (public.is_care_staff()) with check (public.is_care_staff());
create policy "active surveys readable" on public.surveys for select using (active);
create policy "survey response owner or assigned staff" on public.survey_responses for select using (exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) or public.can_access_participant(participant_id));
create policy "survey response owner create" on public.survey_responses for insert with check (exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) or public.can_access_participant(participant_id));
create policy "programs visible" on public.programs for select using (true);
create policy "program staff manage" on public.programs for all using (public.is_staff()) with check (public.is_staff());
create policy "enrollment owner or staff" on public.enrollments for select using (exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) or public.is_staff());
create policy "enrollment staff manage" on public.enrollments for all using (public.is_staff()) with check (public.is_staff());
create policy "case notes assigned staff read" on public.case_notes for select using (public.can_access_participant(participant_id) and (sensitivity='standard' or public.is_admin_or_supervisor() or author_id=auth.uid()));
create policy "case notes assigned staff create" on public.case_notes for insert with check (public.can_access_participant(participant_id) and author_id=auth.uid());
create policy "case notes author or supervisor update" on public.case_notes for update using ((public.can_access_participant(participant_id) and author_id=auth.uid()) or public.is_admin_or_supervisor()) with check (public.is_care_staff());
create policy "participant documents assigned staff read" on public.participant_documents for select using (public.can_access_participant(participant_id) and (sensitivity='standard' or public.is_admin_or_supervisor() or uploaded_by=auth.uid()));
create policy "participant documents assigned staff insert" on public.participant_documents for insert with check (public.can_access_participant(participant_id) and uploaded_by=auth.uid() and consent_confirmed);
create policy "participant feedback owner or assigned staff read" on public.participant_feedback for select using (exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) or public.can_access_participant(participant_id));
create policy "participant feedback owner or assigned staff create" on public.participant_feedback for insert with check (exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) or public.can_access_participant(participant_id));
create policy "participant feedback assigned staff update" on public.participant_feedback for update using (public.can_access_participant(participant_id)) with check (public.can_access_participant(participant_id));
create policy "participant flags assigned staff read" on public.participant_flags for select using (public.can_access_participant(participant_id) and (sensitivity='standard' or public.is_admin_or_supervisor() or created_by=auth.uid()));
create policy "participant flags assigned staff create" on public.participant_flags for insert with check (public.can_access_participant(participant_id) and created_by=auth.uid());
create policy "participant flags supervisor update" on public.participant_flags for update using (public.is_admin_or_supervisor()) with check (public.is_admin_or_supervisor());
create policy "milestones assigned staff or owner read" on public.progress_milestones for select using (public.can_access_participant(participant_id) or exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()));
create policy "milestones assigned staff manage" on public.progress_milestones for all using (public.can_access_participant(participant_id)) with check (public.can_access_participant(participant_id));
create policy "attendance assigned staff or owner read" on public.attendance for select using (public.can_access_participant(participant_id) or exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()));
create policy "attendance assigned staff manage" on public.attendance for all using (public.can_access_participant(participant_id)) with check (public.can_access_participant(participant_id));
create policy "income assigned staff only" on public.income_snapshots for select using (public.can_access_participant(participant_id));
create policy "income field capture" on public.income_snapshots for insert with check (public.can_access_participant(participant_id));
create policy "level history staff or owner" on public.level_transitions for select using (public.can_access_participant(participant_id) or exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()));
create policy "level transition admin" on public.level_transitions for all using (public.is_admin_or_supervisor()) with check (public.is_admin_or_supervisor());
create policy "partners care staff only" on public.partners for select using (public.is_care_staff());
create policy "partners admin manage" on public.partners for all using (public.is_admin_or_supervisor()) with check (public.is_admin_or_supervisor());
create policy "referrals assigned staff or owner" on public.referrals for select using (public.can_access_participant(participant_id) or exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()));
create policy "referrals assigned staff manage" on public.referrals for all using (public.can_access_participant(participant_id)) with check (public.can_access_participant(participant_id));
create policy "outreach care staff read" on public.outreach_events for select using (public.is_care_staff());
create policy "outreach care staff manage" on public.outreach_events for all using (public.is_care_staff()) with check (public.is_care_staff());
create policy "impact care staff read" on public.impact_stories for select using (public.is_care_staff() and publication_status <> 'published' or publication_status='published');
create policy "impact care staff manage" on public.impact_stories for all using (public.is_care_staff()) with check (public.is_care_staff());
create policy "finance restricted read" on public.finance_entries for select using (public.current_role() in ('admin','supervisor','finance_officer'));
create policy "finance authorized insert" on public.finance_entries for insert with check (public.current_role() in ('admin','finance_officer'));
create policy "finance authorized update" on public.finance_entries for update using (public.current_role() in ('admin','finance_officer','supervisor')) with check (public.current_role() in ('admin','finance_officer','supervisor'));
create policy "message participant or assigned staff read" on public.messages for select using (exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid()) or public.can_access_participant(participant_id));
create policy "message participant or assigned staff create" on public.messages for insert with check ((sender_id=auth.uid() and exists(select 1 from public.participants p where p.id=participant_id and p.user_id=auth.uid())) or (sender_id=auth.uid() and public.can_access_participant(participant_id)));
create policy "message assigned staff update" on public.messages for update using (public.can_access_participant(participant_id)) with check (public.can_access_participant(participant_id));
create policy "activity staff or owner read" on public.activity_events for select using (public.is_staff() or actor_id=auth.uid());
create policy "activity authenticated create" on public.activity_events for insert with check (auth.uid() is not null);
create policy "audit admin read" on public.audit_logs for select using (public.is_admin_or_supervisor());

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public
as $$ begin
  insert into public.profiles(id, full_name, preferred_language)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name',''), coalesce(new.raw_user_meta_data->>'preferred_language','en'));
  return new;
end $$;
create or replace function public.prevent_role_escalation() returns trigger
language plpgsql security definer set search_path = public
as $$ begin
  if new.role is distinct from old.role and old.id = auth.uid() and old.role <> 'admin' then
    raise exception 'Only an administrator can change staff roles';
  end if;
  return new;
end $$;
create or replace function public.enforce_level_transition_approval() returns trigger
language plpgsql security definer set search_path = public
as $$ begin
  if new.current_level is distinct from old.current_level then
    if public.current_role() not in ('admin','supervisor') then
      raise exception 'A supervisor must approve participant level changes';
    end if;
    insert into public.level_transitions(participant_id,from_level,to_level,reason,approved_by)
    values(new.id,old.current_level,new.current_level,'Supervisor-approved level transition',auth.uid());
  end if;
  return new;
end $$;
create or replace function public.write_audit_log() returns trigger
language plpgsql security definer set search_path = public
as $$ declare before_row jsonb; after_row jsonb; target_id uuid; changed_fields text[]; begin
  if tg_op <> 'INSERT' then before_row := to_jsonb(old); target_id := old.id; end if;
  if tg_op <> 'DELETE' then after_row := to_jsonb(new); target_id := new.id; end if;
  if tg_op = 'INSERT' then
    select coalesce(array_agg(key),'{}') into changed_fields from jsonb_each(after_row) where value <> 'null'::jsonb;
  elsif tg_op = 'UPDATE' then
    select coalesce(array_agg(key),'{}') into changed_fields from jsonb_each(after_row) e where before_row->key is distinct from e.value;
  else changed_fields := '{}'; end if;
  insert into public.audit_logs(actor_id,action,table_name,record_id,details)
  values(auth.uid(),lower(tg_op),tg_table_name,target_id,jsonb_build_object('changed_fields',changed_fields));
  if tg_op = 'DELETE' then return old; else return new; end if;
end $$;
create trigger audit_participant_change after insert or update or delete on public.participants for each row execute procedure public.write_audit_log();
create trigger audit_application_change after insert or update or delete on public.applications for each row execute procedure public.write_audit_log();
create trigger audit_finance_change after insert or update or delete on public.finance_entries for each row execute procedure public.write_audit_log();
create trigger audit_case_note_change after insert or update or delete on public.case_notes for each row execute procedure public.write_audit_log();
create trigger audit_participant_document_change after insert or update or delete on public.participant_documents for each row execute procedure public.write_audit_log();
create trigger audit_participant_flag_change after insert or update or delete on public.participant_flags for each row execute procedure public.write_audit_log();
create trigger audit_referral_change after insert or update or delete on public.referrals for each row execute procedure public.write_audit_log();
create trigger audit_transition_change after insert or update or delete on public.level_transitions for each row execute procedure public.write_audit_log();
create trigger protect_profile_role before update on public.profiles
for each row execute procedure public.prevent_role_escalation();
create trigger require_level_transition_approval before update on public.participants
for each row execute procedure public.enforce_level_transition_approval();
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Staff roles must be granted by a trusted administrator through the Supabase dashboard or a reviewed admin function.
revoke all on function public.current_role() from public;
revoke all on function public.is_staff() from public;
revoke all on function public.is_admin_or_supervisor() from public;
revoke all on function public.is_care_staff() from public;
revoke all on function public.can_access_participant(uuid) from public;
revoke all on function public.write_audit_log() from public;
revoke all on function public.enforce_level_transition_approval() from public;
grant execute on function public.current_role() to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_admin_or_supervisor() to authenticated;
grant execute on function public.is_care_staff() to authenticated;
grant execute on function public.can_access_participant(uuid) to authenticated;
