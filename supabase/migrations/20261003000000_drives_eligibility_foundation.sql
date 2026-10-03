-- Phase 7: relational criteria, caller-bound projections, atomic audited mutations.
-- Never invent criteria or lifecycle timestamps for incompatible historical data.
do $$
begin
  if exists (
    select 1 from public.placement_drives d
    join public.companies c on c.id = d.company_id
    where (d.status = 'PUBLISHED' and (c.is_archived
      or not exists (select 1 from public.drive_eligibility e where e.drive_id = d.id)
      or not exists (select 1 from public.drive_eligible_batches b where b.drive_id = d.id)))
      or (d.status in ('CLOSED', 'ARCHIVED') and d.closed_at is null)
      or (d.status = 'ARCHIVED' and d.published_at is null)
      or d.published_at < d.created_at or d.closed_at < d.published_at
      or d.archived_at < d.closed_at
  ) then
    raise exception using errcode = '23514', message = 'Historical drives require explicit operator review before Phase 7.';
  end if;
end;
$$;

alter table public.placement_drives
  add column revision integer not null default 1 check (revision > 0),
  add column last_material_change_notice text,
  add column last_material_change_at timestamptz,
  add constraint drives_material_notice_check check (
    (last_material_change_notice is null and last_material_change_at is null)
    or (last_material_change_notice is not null and last_material_change_at is not null
      and char_length(btrim(last_material_change_notice)) between 1 and 2000)
  ),
  add constraint drives_chronology_check check (
    (status = 'DRAFT' and published_at is null and closed_at is null and archived_at is null and archived_by is null)
    or (status = 'PUBLISHED' and published_at is not null and published_at >= created_at and closed_at is null and archived_at is null and archived_by is null)
    or (status = 'CLOSED' and published_at is not null and closed_at is not null and published_at >= created_at and closed_at >= published_at and archived_at is null and archived_by is null)
    or (status = 'ARCHIVED' and published_at is not null and closed_at is not null and archived_at is not null and published_at >= created_at and closed_at >= published_at and archived_at >= closed_at and archived_by is not null)
  );

create function private.drive_projection(p_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', d.id, 'company_id', d.company_id, 'company_name', c.name,
    'title', d.title, 'drive_type', d.drive_type, 'description', d.description,
    'location', d.location, 'application_deadline', d.application_deadline,
    'package_lpa', d.package_lpa, 'stipend_monthly', d.stipend_monthly,
    'compensation_details', d.compensation_details, 'status', d.status,
    'revision', d.revision, 'last_material_change_notice', d.last_material_change_notice,
    'last_material_change_at', d.last_material_change_at,
    'minimum_cgpa', e.minimum_cgpa, 'maximum_active_backlogs', e.maximum_active_backlogs,
    'exclude_previously_selected_placement', e.exclude_previously_selected_placement,
    'informational_requirements', e.informational_requirements,
    'eligible_pairs', coalesce((select jsonb_agg(jsonb_build_object('course', b.course, 'batch_year', b.batch_year)
      order by b.course, b.batch_year) from public.drive_eligible_batches b where b.drive_id = d.id), '[]'::jsonb)
  ) from public.placement_drives d join public.companies c on c.id = d.company_id
    left join public.drive_eligibility e on e.drive_id = d.id where d.id = p_id;
$$;

-- Query-free formatter for bounded set-based list reads.
create function private.drive_eligibility_input(e public.drive_eligibility,p_pairs jsonb,p_deadline timestamptz)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('minimum_cgpa',e.minimum_cgpa,'maximum_active_backlogs',e.maximum_active_backlogs,
    'exclude_previously_selected_placement',e.exclude_previously_selected_placement,
    'eligible_pairs',coalesce(p_pairs,'[]'::jsonb),'application_deadline',p_deadline);
$$;

-- JSON is a bounded transport envelope only; all criteria persist relationally.
create function private.validate_drive_content(p jsonb) returns void
language plpgsql immutable set search_path = '' as $$
declare v_pair jsonb;
begin
  if jsonb_typeof(p) is distinct from 'object' or exists (
    select 1 from jsonb_object_keys(p) k where k not in (
      'company_id','title','drive_type','description','location','application_deadline',
      'package_lpa','stipend_monthly','compensation_details','minimum_cgpa',
      'maximum_active_backlogs','exclude_previously_selected_placement',
      'informational_requirements','eligible_pairs'))
    or jsonb_typeof(p->'title') is distinct from 'string'
    or jsonb_typeof(p->'description') is distinct from 'string'
    or jsonb_typeof(p->'company_id') is distinct from 'string'
    or jsonb_typeof(p->'drive_type') is distinct from 'string'
    or jsonb_typeof(p->'application_deadline') is distinct from 'string'
    or coalesce(char_length(btrim(p->>'title')),0) not between 1 and 200
    or coalesce(char_length(btrim(p->>'description')),0) not between 1 and 10000
    or coalesce(p->>'drive_type','') not in ('PLACEMENT','INTERNSHIP')
    or coalesce(p->>'company_id','') = '' or coalesce(p->>'application_deadline','') = ''
    or char_length(coalesce(p->>'location','')) > 200
    or char_length(coalesce(p->>'compensation_details','')) > 2000
    or char_length(coalesce(p->>'informational_requirements','')) > 4000
    or jsonb_typeof(p->'minimum_cgpa') is distinct from 'number'
    or (p->>'minimum_cgpa')::numeric not between 0 and 10
    or (p->>'minimum_cgpa')::numeric <> round((p->>'minimum_cgpa')::numeric,2)
    or jsonb_typeof(p->'maximum_active_backlogs') is distinct from 'number'
    or (p->>'maximum_active_backlogs')::numeric not between 0 and 50
    or (p->>'maximum_active_backlogs')::numeric <> trunc((p->>'maximum_active_backlogs')::numeric)
    or jsonb_typeof(p->'exclude_previously_selected_placement') is distinct from 'boolean'
    or jsonb_typeof(p->'eligible_pairs') is distinct from 'array'
  then raise exception using errcode = '23514', message = 'Invalid drive content or criteria.'; end if;
  foreach v_pair in array array[p->'location',p->'compensation_details',p->'informational_requirements'] loop
    if v_pair is not null and jsonb_typeof(v_pair) not in ('string','null') then
      raise exception using errcode = '23514', message = 'Optional drive content must be text or null.';
    end if;
  end loop;
  if jsonb_array_length(p->'eligible_pairs') not between 1 and 100 then
    raise exception using errcode = '23514', message = 'Provide between one and 100 explicit course/batch pairs.';
  end if;
  foreach v_pair in array array[p->'package_lpa',p->'stipend_monthly'] loop
    if v_pair is not null and v_pair <> 'null'::jsonb and
      (jsonb_typeof(v_pair) <> 'number' or (v_pair #>> '{}')::numeric not between 0 and 99999999.99) then
      raise exception using errcode = '23514', message = 'Invalid compensation.';
    end if;
  end loop;
  for v_pair in select value from jsonb_array_elements(p->'eligible_pairs') loop
    if jsonb_typeof(v_pair) <> 'object' or jsonb_typeof(v_pair->'course') is distinct from 'string'
      or coalesce(char_length(btrim(v_pair->>'course')),0) not between 1 and 120
      or jsonb_typeof(v_pair->'batch_year') is distinct from 'number'
      or (v_pair->>'batch_year')::numeric not between 2000 and 2200
      or (v_pair->>'batch_year')::numeric <> trunc((v_pair->>'batch_year')::numeric)
      or exists (select 1 from jsonb_object_keys(v_pair) k where k not in ('course','batch_year')) then
      raise exception using errcode = '23514', message = 'Invalid explicit course/batch pair.';
    end if;
  end loop;
  if exists (select 1 from jsonb_array_elements(p->'eligible_pairs') x
    group by btrim(x->>'course'), (x->>'batch_year')::integer having count(*) > 1) then
    raise exception using errcode = '23514', message = 'Duplicate course/batch pairs.';
  end if;
end;
$$;

-- Triggers guard lifecycle/immutability even for accidental privileged SQL.
create or replace function public.enforce_drive_lifecycle() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'DRAFT' then raise exception using errcode = '23514', message = 'A drive must start as a draft.'; end if;
    return new;
  end if;
  if new.status <> old.status and not (
    (old.status = 'DRAFT' and new.status = 'PUBLISHED') or
    (old.status = 'PUBLISHED' and new.status = 'CLOSED') or
    (old.status = 'CLOSED' and new.status = 'ARCHIVED')) then
    raise exception using errcode = '23514', message = 'Invalid drive lifecycle transition.';
  end if;
  return new;
end;
$$;

create function private.guard_drive_update() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_content_changed boolean;
begin
  v_content_changed := (to_jsonb(new) - array['status','published_at','closed_at','archived_at','archived_by','updated_at','updated_by','revision'])
    is distinct from (to_jsonb(old) - array['status','published_at','closed_at','archived_at','archived_by','updated_at','updated_by','revision']);
  if old.status = 'ARCHIVED' or (old.status = 'CLOSED' and
    (new.status <> 'ARCHIVED' or v_content_changed or new.published_at is distinct from old.published_at
      or new.closed_at is distinct from old.closed_at)) then
    raise exception using errcode = '23514', message = 'Closed and archived drive content is immutable.';
  end if;
  if old.status <> 'DRAFT' and (new.company_id <> old.company_id or new.drive_type <> old.drive_type
    or new.published_at is distinct from old.published_at) then
    raise exception using errcode = '23514', message = 'Published company, type and publication timestamp are immutable.';
  end if;
  if old.status = 'PUBLISHED' and v_content_changed then
    if current_setting('app.drive_correction_id', true) is distinct from old.id::text
      or not private.is_phase6_manager() then
      raise exception using errcode = '42501', message = 'Published content requires the protected correction operation.';
    end if;
    if old.application_deadline <= statement_timestamp() and new.application_deadline <> old.application_deadline then
      raise exception using errcode = '23514', message = 'Expired published deadlines cannot be changed.';
    end if;
    if old.application_deadline > statement_timestamp() and new.application_deadline <= statement_timestamp() then
      raise exception using errcode = '23514', message = 'A replacement deadline must be in the future.';
    end if;
  end if;
  if new.status = 'PUBLISHED' and old.status = 'DRAFT' then
    -- Normal procedures already acquired this company lock BEFORE the drive lock.
    perform 1 from public.companies where id = new.company_id and not is_archived for update;
    if not found or new.application_deadline <= statement_timestamp()
      or not exists (select 1 from public.drive_eligibility where drive_id = new.id)
      or not exists (select 1 from public.drive_eligible_batches where drive_id = new.id) then
      raise exception using errcode = '23514', message = 'Publication requires an active company, future deadline and complete criteria.';
    end if;
  end if;
  new.revision := old.revision + 1;
  return new;
end;
$$;
create trigger drives_content_integrity before update on public.placement_drives
for each row execute function private.guard_drive_update();

create function private.prevent_drive_deletion() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception using errcode = '42501', message = 'Drive records must be preserved; use the terminal archive lifecycle.';
end;
$$;
create trigger drives_no_delete before delete on public.placement_drives
for each row execute function private.prevent_drive_deletion();

create function private.guard_drive_criteria() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_state public.drive_status;
begin
  if tg_op = 'UPDATE' and new.drive_id <> old.drive_id then
    raise exception using errcode = '23514', message = 'Criteria ownership is immutable.';
  end if;
  v_id := case when tg_op = 'DELETE' then old.drive_id else new.drive_id end;
  select status into v_state from public.placement_drives where id = v_id for update;
  if v_state in ('CLOSED','ARCHIVED') or (v_state = 'PUBLISHED' and
    (current_setting('app.drive_correction_id', true) is distinct from v_id::text or not private.is_phase6_manager())) then
    raise exception using errcode = '42501', message = 'Drive criteria are locked.';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
create trigger eligibility_content_integrity before insert or update or delete on public.drive_eligibility
for each row execute function private.guard_drive_criteria();
create trigger cohorts_content_integrity before insert or update or delete on public.drive_eligible_batches
for each row execute function private.guard_drive_criteria();

create function private.bump_drive_criteria_revision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_id uuid := case when tg_op = 'DELETE' then old.drive_id else new.drive_id end;
begin
  -- Protected multi-row operations increment the parent once, atomically.
  -- Other privileged SQL criteria writes still invalidate stale forms.
  if current_setting('app.drive_write_id',true) is distinct from v_id::text then
    update public.placement_drives set revision = revision + 1 where id = v_id;
  end if;
  return null;
end;
$$;
create trigger eligibility_revision after insert or update or delete on public.drive_eligibility
for each row execute function private.bump_drive_criteria_revision();
create trigger cohorts_revision after insert or update or delete on public.drive_eligible_batches
for each row execute function private.bump_drive_criteria_revision();

create function private.guard_company_drive_archive() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_archived and exists (select 1 from public.placement_drives where company_id = new.id and status = 'PUBLISHED') then
    raise exception using errcode = '23514', message = 'Close all published drives before archiving this company, including expired drives.';
  end if;
  return new;
end;
$$;
create trigger company_published_drive_integrity before update of is_archived on public.companies
for each row execute function private.guard_company_drive_archive();

create or replace function public.set_company_archive_state(p_company_id uuid, p_is_archived boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := private.require_phase6_staff(false); v_company public.companies%rowtype;
begin
  select * into v_company from public.companies where id = p_company_id for update;
  if not found or p_is_archived is null or v_company.is_archived = p_is_archived then
    raise exception using errcode = '23514', message = 'The company is not in a state that can be changed.';
  end if;
  if p_is_archived and exists (select 1 from public.placement_drives where company_id = p_company_id and status = 'PUBLISHED') then
    raise exception using errcode = '23514', message = 'Close all published drives before archiving this company, including expired drives.';
  end if;
  update public.companies set is_archived = p_is_archived,
    archived_at = case when p_is_archived then statement_timestamp() else null end,
    archived_by = case when p_is_archived then v_actor else null end, updated_by = v_actor where id = p_company_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,before_data,after_data)
  values(v_actor,case when p_is_archived then 'company.archived' else 'company.reactivated' end,
    'company',p_company_id,jsonb_build_object('is_archived',v_company.is_archived),jsonb_build_object('is_archived',p_is_archived));
end;
$$;

create function private.write_drive_criteria(p_id uuid, p jsonb) returns void
language plpgsql set search_path = '' as $$
begin
  insert into public.drive_eligibility(drive_id,minimum_cgpa,maximum_active_backlogs,exclude_previously_selected_placement,informational_requirements)
  values(p_id,(p->>'minimum_cgpa')::numeric,(p->>'maximum_active_backlogs')::smallint,
    (p->>'exclude_previously_selected_placement')::boolean,nullif(btrim(p->>'informational_requirements'),''))
  on conflict(drive_id) do update set minimum_cgpa = excluded.minimum_cgpa,
    maximum_active_backlogs = excluded.maximum_active_backlogs,
    exclude_previously_selected_placement = excluded.exclude_previously_selected_placement,
    informational_requirements = excluded.informational_requirements;
  delete from public.drive_eligible_batches where drive_id = p_id;
  insert into public.drive_eligible_batches(drive_id,course,batch_year)
  select p_id,btrim(x->>'course'),(x->>'batch_year')::smallint from jsonb_array_elements(p->'eligible_pairs') x;
end;
$$;

-- Locks companies in stable UUID order, then the drive. Rechecks the parent
-- after waiting: a concurrent draft company edit must not defeat lock ordering.
create function private.lock_drive(p_id uuid, p_new_company uuid default null)
returns public.placement_drives language plpgsql set search_path = '' as $$
declare v_company uuid; v_drive public.placement_drives%rowtype;
begin
  select company_id into v_company from public.placement_drives where id = p_id;
  perform 1 from public.companies where id in (v_company,p_new_company) order by id for update;
  select * into v_drive from public.placement_drives where id = p_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'Drive unavailable.'; end if;
  if v_drive.company_id is distinct from v_company then
    raise exception using errcode = '40001', message = 'Drive changed; reload before trying again.';
  end if;
  return v_drive;
end;
$$;

create function private.mutate_drive_content(p_content jsonb,p_id uuid,p_revision integer,p_reason text,p_notice text)
returns uuid language plpgsql set search_path = '' as $$
declare v_actor uuid; v_id uuid := p_id; v_old public.placement_drives%rowtype;
  v_before jsonb; v_after jsonb; v_correction boolean := p_reason is not null;
  v_old_flag text := current_setting('app.drive_correction_id',true);
  v_old_write_flag text := current_setting('app.drive_write_id',true);
begin
  v_actor := private.require_phase6_staff(not v_correction);
  perform private.validate_drive_content(p_content);
  if v_id is null then
    if v_correction then raise exception using errcode = '23514', message = 'Correction requires an existing drive.'; end if;
    perform 1 from public.companies where id = (p_content->>'company_id')::uuid and not is_archived for update;
    if not found then raise exception using errcode = '23514', message = 'An active company is required.'; end if;
    insert into public.placement_drives(company_id,title,drive_type,description,location,application_deadline,
      package_lpa,stipend_monthly,compensation_details,created_by,updated_by)
    values((p_content->>'company_id')::uuid,btrim(p_content->>'title'),(p_content->>'drive_type')::public.drive_type,
      btrim(p_content->>'description'),nullif(btrim(p_content->>'location'),''),(p_content->>'application_deadline')::timestamptz,
      (p_content->>'package_lpa')::numeric,(p_content->>'stipend_monthly')::numeric,
      nullif(btrim(p_content->>'compensation_details'),''),v_actor,v_actor) returning id into v_id;
  else
    v_old := private.lock_drive(v_id,(p_content->>'company_id')::uuid);
    if p_revision is null or p_revision <> v_old.revision then
      raise exception using errcode = '40001', message = 'Drive changed; reload before trying again.';
    end if;
    if (v_correction and v_old.status <> 'PUBLISHED') or (not v_correction and v_old.status <> 'DRAFT') then
      raise exception using errcode = '23514', message = 'Drive is not in the required state.';
    end if;
    perform 1 from public.companies where id = (p_content->>'company_id')::uuid and not is_archived;
    if not found then raise exception using errcode = '23514', message = 'An active company is required.'; end if;
    v_before := private.drive_projection(v_id);
    if v_correction then
      if coalesce(char_length(btrim(p_reason)),0) not between 1 and 2000
        or coalesce(char_length(btrim(p_notice)),0) not between 1 and 2000 then
        raise exception using errcode = '23514', message = 'Correction requires an internal reason and a student-facing notice (1–2000 characters each).';
      end if;
      perform set_config('app.drive_correction_id',v_id::text,true);
    end if;
    update public.placement_drives set company_id = (p_content->>'company_id')::uuid,
      title = btrim(p_content->>'title'),drive_type = (p_content->>'drive_type')::public.drive_type,
      description = btrim(p_content->>'description'),location = nullif(btrim(p_content->>'location'),''),
      application_deadline = (p_content->>'application_deadline')::timestamptz,
      package_lpa = (p_content->>'package_lpa')::numeric,stipend_monthly = (p_content->>'stipend_monthly')::numeric,
      compensation_details = nullif(btrim(p_content->>'compensation_details'),''),updated_by = v_actor,
      last_material_change_notice = case when v_correction then btrim(p_notice) else last_material_change_notice end,
      last_material_change_at = case when v_correction then statement_timestamp() else last_material_change_at end
    where id = v_id;
  end if;
  perform set_config('app.drive_write_id',v_id::text,true);
  perform private.write_drive_criteria(v_id,p_content);
  v_after := private.drive_projection(v_id);
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,before_data,after_data)
    values(v_actor,case when p_id is null then 'drive.created' else 'drive.updated' end,'placement_drive',v_id,v_before,
      v_after || case when v_correction then jsonb_build_object('classification','published/material','reason',btrim(p_reason)) else '{}'::jsonb end);
  if p_id is null or (v_before->'eligible_pairs',v_before->'minimum_cgpa',v_before->'maximum_active_backlogs',v_before->'exclude_previously_selected_placement',v_before->'informational_requirements')
    is distinct from (v_after->'eligible_pairs',v_after->'minimum_cgpa',v_after->'maximum_active_backlogs',v_after->'exclude_previously_selected_placement',v_after->'informational_requirements') then
    insert into public.audit_logs(actor_id,action,entity_type,entity_id,before_data,after_data)
      values(v_actor,'drive.eligibility_updated','placement_drive',v_id,v_before,
        v_after || case when v_correction then jsonb_build_object('classification','published/material','reason',btrim(p_reason)) else '{}'::jsonb end);
  end if;
  perform set_config('app.drive_correction_id',coalesce(v_old_flag,''),true);
  perform set_config('app.drive_write_id',coalesce(v_old_write_flag,''),true);
  return v_id;
end;
$$;

create function public.save_drive_draft(p_content jsonb,p_drive_id uuid default null,p_expected_revision integer default null)
returns uuid language sql security definer set search_path = '' as $$
  select private.mutate_drive_content(p_content,p_drive_id,p_expected_revision,null,null);
$$;
create function public.correct_published_drive(p_drive_id uuid,p_expected_revision integer,p_content jsonb,p_reason text,p_notice text)
returns uuid language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_phase6_staff(false);
  if p_reason is null then raise exception using errcode = '23514', message = 'A correction reason is required.'; end if;
  return private.mutate_drive_content(p_content,p_drive_id,p_expected_revision,p_reason,p_notice);
end;
$$;

create function public.transition_drive(p_drive_id uuid,p_expected_revision integer,p_next_status public.drive_status)
returns void language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := private.require_phase6_staff(false); v_old public.placement_drives%rowtype; v_before jsonb;
begin
  v_old := private.lock_drive(p_drive_id);
  if p_expected_revision is null or p_expected_revision <> v_old.revision then
    raise exception using errcode = '40001', message = 'Drive changed; reload before trying again.';
  end if;
  if p_next_status is null or not ((v_old.status = 'DRAFT' and p_next_status = 'PUBLISHED')
    or (v_old.status = 'PUBLISHED' and p_next_status = 'CLOSED') or (v_old.status = 'CLOSED' and p_next_status = 'ARCHIVED')) then
    raise exception using errcode = '23514', message = 'Invalid drive lifecycle transition.';
  end if;
  v_before := private.drive_projection(p_drive_id);
  update public.placement_drives set status = p_next_status,
    published_at = case when p_next_status = 'PUBLISHED' then statement_timestamp() else published_at end,
    closed_at = case when p_next_status = 'CLOSED' then statement_timestamp() else closed_at end,
    archived_at = case when p_next_status = 'ARCHIVED' then statement_timestamp() else archived_at end,
    archived_by = case when p_next_status = 'ARCHIVED' then v_actor else archived_by end, updated_by = v_actor
  where id = p_drive_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,before_data,after_data)
  values(v_actor,'drive.' || lower(p_next_status::text),'placement_drive',p_drive_id,v_before,private.drive_projection(p_drive_id));
end;
$$;

create function private.student_drive_context() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v jsonb;
begin
  if not private.has_active_role(array['STUDENT']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'An active student account is required.';
  end if;
  select jsonb_build_object('course',r.course,'batch_year',r.batch_year,'has_academics',a.student_id is not null,
    'academic_verified',coalesce(a.verification_status = 'VERIFIED',false),
    'cgpa',case when a.verification_status = 'VERIFIED' then a.cgpa end,
    'backlogs',case when a.verification_status = 'VERIFIED' then a.active_backlog_count end,
    'selected_placement',exists(select 1 from public.applications ap join public.placement_drives pd on pd.id = ap.drive_id
      where ap.student_id = auth.uid() and ap.current_status = 'SELECTED' and pd.drive_type = 'PLACEMENT'))
    into v from public.student_profiles s join public.student_roster r on r.id = s.roster_id
    left join public.academic_records a on a.student_id = s.user_id where s.user_id = auth.uid();
  if v is null then raise exception using errcode = '42501', message = 'A provisioned student account is required.'; end if;
  return v;
end;
$$;

-- One calculation. The context/time arguments are PRIVATE, never client RPC inputs.
create function private.calculate_drive_eligibility(d jsonb,s jsonb,t timestamptz) returns jsonb
language plpgsql stable set search_path = '' as $$
declare reasons text[] := array[]::text[]; academic_reasons text[] := array[]::text[]; result text := 'PASS';
  is_open boolean := (d->>'application_deadline')::timestamptz > t;
begin
  if not is_open then reasons := array_append(reasons,'DEADLINE_PASSED'); end if;
  if d->>'minimum_cgpa' is null or d->>'maximum_active_backlogs' is null
    or d->>'exclude_previously_selected_placement' is null or jsonb_array_length(d->'eligible_pairs') = 0 then
    reasons := array_append(reasons,'DRIVE_CRITERIA_UNAVAILABLE'); result := 'UNDETERMINED';
  end if;
  if not (s->>'has_academics')::boolean then
    academic_reasons := array_append(academic_reasons,'ACADEMIC_DATA_UNAVAILABLE'); result := 'UNDETERMINED';
  elsif not (s->>'academic_verified')::boolean then
    academic_reasons := array_append(academic_reasons,'ACADEMIC_UNVERIFIED'); result := 'UNDETERMINED';
  end if;
  if jsonb_array_length(d->'eligible_pairs') > 0 and not exists(select 1 from jsonb_array_elements(d->'eligible_pairs') p where p->>'course' = s->>'course') then
    academic_reasons := array_append(academic_reasons,'COURSE_NOT_ELIGIBLE');
  elsif jsonb_array_length(d->'eligible_pairs') > 0 and not exists(select 1 from jsonb_array_elements(d->'eligible_pairs') p
    where p->>'course' = s->>'course' and p->>'batch_year' = s->>'batch_year') then
    academic_reasons := array_append(academic_reasons,'BATCH_NOT_ELIGIBLE');
  end if;
  if (s->>'academic_verified')::boolean then
    if (s->>'cgpa')::numeric < (d->>'minimum_cgpa')::numeric then academic_reasons := array_append(academic_reasons,'CGPA_BELOW_MINIMUM'); end if;
    if (s->>'backlogs')::integer > (d->>'maximum_active_backlogs')::integer then academic_reasons := array_append(academic_reasons,'ACTIVE_BACKLOG_LIMIT_EXCEEDED'); end if;
  end if;
  if (d->>'exclude_previously_selected_placement')::boolean and (s->>'selected_placement')::boolean then
    academic_reasons := array_append(academic_reasons,'PREVIOUSLY_SELECTED_PLACEMENT');
  end if;
  if result <> 'UNDETERMINED' and cardinality(academic_reasons) > 0 then result := 'FAIL'; end if;
  reasons := reasons || academic_reasons;
  if cardinality(reasons) = 0 then reasons := array['ELIGIBLE']; end if;
  return jsonb_build_object('academic_result',result,'availability',case when is_open then 'OPEN' else 'DEADLINE_PASSED' end,
    'reason_codes',to_jsonb(reasons),'is_eligible',is_open and result = 'PASS', 'evaluated_at',t);
end;
$$;

create function public.student_drive_detail(p_drive_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s jsonb := private.student_drive_context(); d jsonb; t timestamptz := statement_timestamp();
begin
  if not exists(select 1 from public.placement_drives where id = p_drive_id and status = 'PUBLISHED') then return null; end if;
  d := private.drive_projection(p_drive_id);
  return (d - array['company_id','status']) || jsonb_build_object('eligibility',private.calculate_drive_eligibility(d,s,t));
end;
$$;

create function public.student_drive_list(p_page integer default 1,p_type public.drive_type default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare s jsonb := private.student_drive_context(); t timestamptz := statement_timestamp(); v jsonb;
begin
  -- Context loaded once; SQL filters precede deterministic 20+1 paging.
  with bounded as materialized (
    select d.* from public.placement_drives d
    where d.status = 'PUBLISHED' and (p_type is null or d.drive_type = p_type)
    order by d.application_deadline,d.id limit 21 offset (greatest(1,least(coalesce(p_page,1),10000))-1)*20
  ), pairs as (
    select b.drive_id,jsonb_agg(jsonb_build_object('course',b.course,'batch_year',b.batch_year)
      order by b.course,b.batch_year) eligible_pairs
    from public.drive_eligible_batches b join bounded p on p.id = b.drive_id group by b.drive_id
  )
  select coalesce(jsonb_agg(projection order by deadline,id),'[]'::jsonb) into v from (
    select d.id,d.application_deadline deadline,
      jsonb_build_object('id',d.id,'company_name',c.name,'title',d.title,'drive_type',d.drive_type,
        'location',d.location,'application_deadline',d.application_deadline,
        'last_material_change_notice',d.last_material_change_notice,
        'eligibility',private.calculate_drive_eligibility(private.drive_eligibility_input(e,b.eligible_pairs,d.application_deadline),s,t)) projection
    from bounded d join public.companies c on c.id = d.company_id
    left join public.drive_eligibility e on e.drive_id = d.id left join pairs b on b.drive_id = d.id
  ) page;
  return v;
end;
$$;

create function public.staff_drive_detail(p_drive_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_phase6_staff();
  return private.drive_projection(p_drive_id);
end;
$$;
create function public.staff_drive_list(p_page integer default 1,p_status public.drive_status default 'DRAFT')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v jsonb;
begin
  perform private.require_phase6_staff();
  select coalesce(jsonb_agg(projection order by deadline,id),'[]'::jsonb) into v from (
    select d.id,d.application_deadline deadline,jsonb_build_object('id',d.id,'company_name',c.name,
      'title',d.title,'drive_type',d.drive_type,'status',d.status,'revision',d.revision,
      'application_deadline',d.application_deadline) projection
    from public.placement_drives d join public.companies c on c.id = d.company_id
    where d.status = coalesce(p_status,'DRAFT') order by d.application_deadline,d.id
    limit 21 offset (greatest(1,least(coalesce(p_page,1),10000))-1)*20
  ) page;
  return v;
end;
$$;

-- No base-table/RLS grant expansion: recruiters share the authenticated PG role.
revoke all on function private.drive_projection(uuid),private.validate_drive_content(jsonb),
  private.guard_drive_update(),private.guard_drive_criteria(),private.guard_company_drive_archive(),
  private.write_drive_criteria(uuid,jsonb),private.lock_drive(uuid,uuid),
  private.mutate_drive_content(jsonb,uuid,integer,text,text),private.student_drive_context(),
  private.calculate_drive_eligibility(jsonb,jsonb,timestamptz) from public,anon,authenticated;
revoke all on function private.drive_eligibility_input(public.drive_eligibility,jsonb,timestamptz),
  private.bump_drive_criteria_revision(),private.prevent_drive_deletion() from public,anon,authenticated;
revoke all on function public.save_drive_draft(jsonb,uuid,integer),public.correct_published_drive(uuid,integer,jsonb,text,text),
  public.transition_drive(uuid,integer,public.drive_status),public.student_drive_detail(uuid),
  public.student_drive_list(integer,public.drive_type),public.staff_drive_detail(uuid),public.staff_drive_list(integer,public.drive_status) from public,anon;
grant execute on function public.save_drive_draft(jsonb,uuid,integer),public.correct_published_drive(uuid,integer,jsonb,text,text),
  public.transition_drive(uuid,integer,public.drive_status),public.student_drive_detail(uuid),
  public.student_drive_list(integer,public.drive_type),public.staff_drive_detail(uuid),public.staff_drive_list(integer,public.drive_status) to authenticated;
