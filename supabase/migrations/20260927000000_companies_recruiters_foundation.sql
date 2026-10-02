-- Phase 6: companies, recruiter contacts, invitation lifecycle, and bounded
-- published-drive grants. Drive/application workflows remain deliberately absent.

create type public.recruiter_invitation_status as enum (
  'PREPARED',
  'SENT',
  'ACCEPTED',
  'REVOKED',
  'DELIVERY_FAILED'
);

create table public.recruiter_invitations (
  id uuid primary key default gen_random_uuid(),
  recruiter_id uuid not null references public.recruiters (id) on delete restrict,
  email text not null check (email = lower(btrim(email)) and position('@' in email) > 1),
  status public.recruiter_invitation_status not null default 'PREPARED',
  auth_user_id uuid references auth.users (id) on delete restrict,
  issued_by uuid not null references public.profiles (id) on delete restrict,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references public.profiles (id) on delete restrict,
  revocation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recruiter_invitations_expiry_check check (expires_at > issued_at),
  constraint recruiter_invitations_revocation_reason_check check (
    revocation_reason is null or char_length(btrim(revocation_reason)) between 1 and 2000
  ),
  constraint recruiter_invitations_lifecycle_check check (
    (status = 'PREPARED' and auth_user_id is null and accepted_at is null and revoked_at is null and revoked_by is null and revocation_reason is null)
    or (status = 'SENT' and auth_user_id is not null and accepted_at is null and revoked_at is null and revoked_by is null and revocation_reason is null)
    or (status = 'ACCEPTED' and auth_user_id is not null and accepted_at is not null and revoked_at is null and revoked_by is null and revocation_reason is null)
    or (status = 'REVOKED' and accepted_at is null and revoked_at is not null and revoked_by is not null and revocation_reason is not null)
    or (status = 'DELIVERY_FAILED' and accepted_at is null and revoked_at is null and revoked_by is null and revocation_reason is null)
  )
);

alter table public.companies
  add constraint companies_website_url_https_check
  check (website_url is null or btrim(website_url) ~ '^https://[^[:space:]]+$') not valid;

alter table public.recruiter_drive_access
  add column revoked_at timestamptz,
  add column revoked_by uuid references public.profiles (id) on delete restrict,
  add column revocation_reason text,
  add column updated_at timestamptz not null default now(),
  add constraint recruiter_drive_access_revocation_reason_check check (
    revocation_reason is null or char_length(btrim(revocation_reason)) between 1 and 2000
  ),
  add constraint recruiter_drive_access_revocation_check check (
    (revoked_at is null and revoked_by is null and revocation_reason is null)
    or (revoked_at is not null and revoked_by is not null and revocation_reason is not null)
  );

create index companies_list_idx on public.companies (is_archived, normalized_name, id);
create index recruiters_company_list_idx on public.recruiters (company_id, is_archived, full_name, id);
create index recruiter_invitations_recruiter_created_idx
  on public.recruiter_invitations (recruiter_id, created_at desc);
create index recruiter_invitations_active_lookup_idx
  on public.recruiter_invitations (email, expires_at)
  where status in ('PREPARED', 'SENT');
create unique index recruiter_invitations_one_active_per_recruiter_idx
  on public.recruiter_invitations (recruiter_id)
  where status in ('PREPARED', 'SENT');
create unique index recruiter_invitations_active_auth_user_idx
  on public.recruiter_invitations (auth_user_id)
  where auth_user_id is not null and status in ('SENT', 'ACCEPTED');

create trigger recruiter_invitations_set_updated_at
before update on public.recruiter_invitations
for each row execute function public.set_updated_at();

create trigger recruiter_drive_access_set_updated_at
before update on public.recruiter_drive_access
for each row execute function public.set_updated_at();

create or replace function public.prevent_recruiter_identity_rebinding()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.user_id is not null and new.user_id is distinct from old.user_id then
    raise exception 'A bound recruiter account cannot be rebound' using errcode = '23514';
  end if;

  if old.user_id is not null and new.company_id is distinct from old.company_id then
    raise exception 'A bound recruiter contact cannot be moved to another company' using errcode = '23514';
  end if;

  if new.email is distinct from old.email and exists (
    select 1 from public.recruiter_invitations as invitation
    where invitation.recruiter_id = old.id
  ) then
    raise exception 'A recruiter email cannot change after invitation preparation' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger recruiters_prevent_identity_rebinding
before update of user_id, company_id, email on public.recruiters
for each row execute function public.prevent_recruiter_identity_rebinding();

create or replace function private.is_phase6_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_active_role(array[
    'SUPER_ADMIN'::public.app_role,
    'TNP_SECRETARY'::public.app_role,
    'TNP_COORDINATOR'::public.app_role
  ]);
$$;

create or replace function private.is_phase6_manager()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]);
$$;

create or replace function private.can_mutate_company_draft(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.companies as company
    where company.id = p_company_id
      and company.created_by = (select auth.uid())
      and not company.is_archived
      and not exists (
        select 1
        from public.recruiters as recruiter
        join public.recruiter_invitations as invitation on invitation.recruiter_id = recruiter.id
        where recruiter.company_id = company.id
      )
  );
$$;

create or replace function private.can_mutate_recruiter_draft(p_recruiter_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.recruiters as recruiter
    join public.companies as company on company.id = recruiter.company_id
    where recruiter.id = p_recruiter_id
      and recruiter.created_by = (select auth.uid())
      and not recruiter.is_archived
      and not company.is_archived
      and not exists (
        select 1 from public.recruiter_invitations as invitation where invitation.recruiter_id = recruiter.id
      )
  );
$$;

create or replace function private.current_active_recruiter_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select recruiter.id
  from public.recruiters as recruiter
  join public.companies as company on company.id = recruiter.company_id
  join public.profiles as profile on profile.id = recruiter.user_id
  where recruiter.user_id = (select auth.uid())
    and not recruiter.is_archived
    and not company.is_archived
    and profile.is_active
    and profile.role = 'RECRUITER'::public.app_role
  limit 1;
$$;

create or replace function private.can_read_recruiter_company(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.recruiters as recruiter
    join public.companies as company on company.id = recruiter.company_id
    join public.profiles as profile on profile.id = recruiter.user_id
    where company.id = p_company_id
      and recruiter.user_id = (select auth.uid())
      and not recruiter.is_archived
      and not company.is_archived
      and profile.is_active
      and profile.role = 'RECRUITER'::public.app_role
  );
$$;

create or replace function private.can_read_recruiter_published_drive(p_drive_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.recruiter_drive_access as access
    join public.recruiters as recruiter on recruiter.id = access.recruiter_id
    join public.companies as company on company.id = recruiter.company_id
    join public.profiles as profile on profile.id = recruiter.user_id
    join public.placement_drives as drive on drive.id = access.drive_id
    where access.drive_id = p_drive_id
      and recruiter.user_id = (select auth.uid())
      and not recruiter.is_archived
      and not company.is_archived
      and profile.is_active
      and profile.role = 'RECRUITER'::public.app_role
      and drive.company_id = company.id
      and drive.status = 'PUBLISHED'::public.drive_status
      and access.revoked_at is null
      and (access.expires_at is null or access.expires_at > now())
  );
$$;

revoke all on function private.is_phase6_staff() from public, anon;
revoke all on function private.is_phase6_manager() from public, anon;
revoke all on function private.can_mutate_company_draft(uuid) from public, anon;
revoke all on function private.can_mutate_recruiter_draft(uuid) from public, anon;
revoke all on function private.current_active_recruiter_id() from public, anon;
revoke all on function private.can_read_recruiter_company(uuid) from public, anon;
revoke all on function private.can_read_recruiter_published_drive(uuid) from public, anon;
grant execute on function private.is_phase6_staff() to authenticated;
grant execute on function private.is_phase6_manager() to authenticated;
grant execute on function private.current_active_recruiter_id() to authenticated;
grant execute on function private.can_read_recruiter_company(uuid) to authenticated;
grant execute on function private.can_read_recruiter_published_drive(uuid) to authenticated;

create or replace function private.require_phase6_staff(p_allow_coordinator boolean default true)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null or not private.is_phase6_staff() then
    raise exception 'An active TNP staff account is required' using errcode = '42501';
  end if;

  if not p_allow_coordinator and not private.is_phase6_manager() then
    raise exception 'Only the TNP Secretary or Super Admin may perform this operation' using errcode = '42501';
  end if;

  return v_actor_id;
end;
$$;

revoke all on function private.require_phase6_staff(boolean) from public, anon;

create or replace function public.create_company(
  p_name text,
  p_website_url text,
  p_description text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(true);
  v_company_id uuid;
  v_website_url text := nullif(btrim(p_website_url), '');
  v_description text := nullif(btrim(p_description), '');
begin
  if p_name is null or char_length(btrim(p_name)) not between 1 and 160
    or (v_website_url is not null and v_website_url !~ '^https://[^[:space:]]+$')
    or (v_description is not null and char_length(v_description) > 4000) then
    raise exception 'Valid company details are required' using errcode = '23514';
  end if;

  insert into public.companies (name, website_url, description, created_by, updated_by)
  values (btrim(p_name), v_website_url, v_description, v_actor_id, v_actor_id)
  returning id into v_company_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'company.created', 'company', v_company_id, jsonb_build_object('name', btrim(p_name)));
  return v_company_id;
end;
$$;

create or replace function public.update_company(
  p_company_id uuid,
  p_name text,
  p_website_url text,
  p_description text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(true);
  v_company public.companies%rowtype;
  v_website_url text := nullif(btrim(p_website_url), '');
  v_description text := nullif(btrim(p_description), '');
begin
  if p_name is null or char_length(btrim(p_name)) not between 1 and 160
    or (v_website_url is not null and v_website_url !~ '^https://[^[:space:]]+$')
    or (v_description is not null and char_length(v_description) > 4000) then
    raise exception 'Valid company details are required' using errcode = '23514';
  end if;

  select * into v_company from public.companies where id = p_company_id for update;
  if not found or v_company.is_archived then
    raise exception 'The company is unavailable' using errcode = '42501';
  end if;
  if not private.is_phase6_manager() and not private.can_mutate_company_draft(p_company_id) then
    raise exception 'Only the creator may edit an uninvited company draft' using errcode = '42501';
  end if;

  update public.companies
  set name = btrim(p_name), website_url = v_website_url, description = v_description, updated_by = v_actor_id
  where id = p_company_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (
    v_actor_id,
    'company.updated',
    'company',
    p_company_id,
    jsonb_build_object('name', v_company.name, 'website_url', v_company.website_url, 'description', v_company.description),
    jsonb_build_object('name', btrim(p_name), 'website_url', v_website_url, 'description', v_description)
  );
end;
$$;

create or replace function public.set_company_archive_state(p_company_id uuid, p_is_archived boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(false);
  v_company public.companies%rowtype;
begin
  select * into v_company from public.companies where id = p_company_id for update;
  if not found or v_company.is_archived = p_is_archived then
    raise exception 'The company is not in a state that can be changed' using errcode = '23514';
  end if;

  update public.companies
  set is_archived = p_is_archived,
      archived_at = case when p_is_archived then now() else null end,
      archived_by = case when p_is_archived then v_actor_id else null end,
      updated_by = v_actor_id
  where id = p_company_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (
    v_actor_id,
    case when p_is_archived then 'company.archived' else 'company.reactivated' end,
    'company',
    p_company_id,
    jsonb_build_object('is_archived', v_company.is_archived),
    jsonb_build_object('is_archived', p_is_archived)
  );
end;
$$;

create or replace function public.create_recruiter_contact(
  p_company_id uuid,
  p_full_name text,
  p_email text,
  p_phone_number text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(true);
  v_recruiter_id uuid;
  v_email text := lower(btrim(p_email));
  v_phone_number text := nullif(btrim(p_phone_number), '');
begin
  if p_full_name is null or char_length(btrim(p_full_name)) not between 1 and 160
    or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    or (v_phone_number is not null and v_phone_number !~ '^[0-9+() -]{7,30}$') then
    raise exception 'Valid recruiter contact details are required' using errcode = '23514';
  end if;
  if not exists (select 1 from public.companies where id = p_company_id and not is_archived) then
    raise exception 'An active company is required' using errcode = '23514';
  end if;
  if not private.is_phase6_manager() and not private.can_mutate_company_draft(p_company_id) then
    raise exception 'Only the creator may add a contact to an uninvited company draft' using errcode = '42501';
  end if;

  insert into public.recruiters (company_id, full_name, email, phone_number, created_by, updated_by)
  values (p_company_id, btrim(p_full_name), v_email, v_phone_number, v_actor_id, v_actor_id)
  returning id into v_recruiter_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'recruiter.created', 'recruiter', v_recruiter_id, jsonb_build_object('company_id', p_company_id));
  return v_recruiter_id;
end;
$$;

create or replace function public.update_recruiter_contact(
  p_recruiter_id uuid,
  p_full_name text,
  p_email text,
  p_phone_number text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(true);
  v_recruiter public.recruiters%rowtype;
  v_email text := lower(btrim(p_email));
  v_phone_number text := nullif(btrim(p_phone_number), '');
begin
  if p_full_name is null or char_length(btrim(p_full_name)) not between 1 and 160
    or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    or (v_phone_number is not null and v_phone_number !~ '^[0-9+() -]{7,30}$') then
    raise exception 'Valid recruiter contact details are required' using errcode = '23514';
  end if;

  select * into v_recruiter from public.recruiters where id = p_recruiter_id for update;
  if not found or v_recruiter.is_archived then
    raise exception 'The recruiter contact is unavailable' using errcode = '42501';
  end if;
  if not private.is_phase6_manager() and not private.can_mutate_recruiter_draft(p_recruiter_id) then
    raise exception 'Only the creator may edit an uninvited recruiter draft' using errcode = '42501';
  end if;

  update public.recruiters
  set full_name = btrim(p_full_name), email = v_email, phone_number = v_phone_number, updated_by = v_actor_id
  where id = p_recruiter_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (
    v_actor_id,
    'recruiter.updated',
    'recruiter',
    p_recruiter_id,
    jsonb_build_object('full_name', v_recruiter.full_name, 'email', v_recruiter.email, 'phone_number', v_recruiter.phone_number),
    jsonb_build_object('full_name', btrim(p_full_name), 'email', v_email, 'phone_number', v_phone_number)
  );
end;
$$;

create or replace function public.set_recruiter_archive_state(p_recruiter_id uuid, p_is_archived boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(false);
  v_recruiter public.recruiters%rowtype;
begin
  select * into v_recruiter from public.recruiters where id = p_recruiter_id for update;
  if not found or v_recruiter.is_archived = p_is_archived then
    raise exception 'The recruiter is not in a state that can be changed' using errcode = '23514';
  end if;
  if not p_is_archived and not exists (
    select 1 from public.companies where id = v_recruiter.company_id and not is_archived
  ) then
    raise exception 'The recruiter company is unavailable' using errcode = '23514';
  end if;
  if not p_is_archived and v_recruiter.user_id is not null and not exists (
    select 1
    from public.profiles as profile
    where profile.id = v_recruiter.user_id
      and profile.is_active
      and profile.role = 'RECRUITER'::public.app_role
  ) then
    raise exception 'An active recruiter account is required to reactivate this binding' using errcode = '23514';
  end if;

  update public.recruiters
  set is_archived = p_is_archived,
      archived_at = case when p_is_archived then now() else null end,
      archived_by = case when p_is_archived then v_actor_id else null end,
      updated_by = v_actor_id
  where id = p_recruiter_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (
    v_actor_id,
    case when p_is_archived then 'recruiter.archived' else 'recruiter.reactivated' end,
    'recruiter',
    p_recruiter_id,
    jsonb_build_object('is_archived', v_recruiter.is_archived),
    jsonb_build_object('is_archived', p_is_archived)
  );
end;
$$;

create or replace function public.prepare_recruiter_invitation(p_recruiter_id uuid, p_is_reissue boolean default false)
returns table (invitation_id uuid, invitation_email text, invitation_expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(false);
  v_recruiter public.recruiters%rowtype;
  v_existing public.recruiter_invitations%rowtype;
  v_expires_at timestamptz := now() + interval '1 hour';
begin
  select recruiter.* into v_recruiter
  from public.recruiters as recruiter
  join public.companies as company on company.id = recruiter.company_id
  where recruiter.id = p_recruiter_id and not recruiter.is_archived and not company.is_archived
  for update of recruiter;
  if not found or v_recruiter.user_id is not null then
    raise exception 'An active unbound recruiter contact is required' using errcode = '23514';
  end if;

  select * into v_existing
  from public.recruiter_invitations
  where recruiter_id = p_recruiter_id and status in ('PREPARED', 'SENT')
  for update;

  if found and not p_is_reissue then
    raise exception 'An active invitation already exists' using errcode = '23505';
  end if;
  if found then
    update public.recruiter_invitations
    set status = 'REVOKED', revoked_at = now(), revoked_by = v_actor_id, revocation_reason = 'Superseded by reissue'
    where id = v_existing.id;
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
    values (v_actor_id, 'recruiter.invitation_revoked', 'recruiter_invitation', v_existing.id, jsonb_build_object('reason', 'Superseded by reissue'));
  elsif p_is_reissue then
    if not exists (
      select 1 from public.recruiter_invitations where recruiter_id = p_recruiter_id
    ) then
      raise exception 'Only a previously invited recruiter may be reissued an invitation' using errcode = '23514';
    end if;
  end if;

  insert into public.recruiter_invitations (recruiter_id, email, issued_by, expires_at)
  values (p_recruiter_id, v_recruiter.email, v_actor_id, v_expires_at)
  returning id, email, expires_at into invitation_id, invitation_email, invitation_expires_at;

  update public.recruiters
  set invitation_expires_at = v_expires_at, updated_by = v_actor_id
  where id = p_recruiter_id;
  return next;
end;
$$;

create or replace function public.mark_recruiter_invitation_sent(
  p_invitation_id uuid,
  p_auth_user_id uuid,
  p_is_reissue boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(false);
  v_invitation public.recruiter_invitations%rowtype;
  v_auth_email text;
  v_metadata_invitation_id text;
  v_has_superseded_auth_invitation boolean;
begin
  select * into v_invitation from public.recruiter_invitations where id = p_invitation_id for update;
  if not found or v_invitation.status <> 'PREPARED' or v_invitation.expires_at <= now() then
    raise exception 'The invitation is no longer ready to send' using errcode = '23514';
  end if;

  select lower(btrim(user_record.email)), user_record.raw_user_meta_data ->> 'recruiter_invitation_id'
  into v_auth_email, v_metadata_invitation_id
  from auth.users as user_record
  where user_record.id = p_auth_user_id;
  if not found or v_auth_email <> v_invitation.email then
    raise exception 'The Auth invitation identity does not match the recruiter invitation' using errcode = '23514';
  end if;

  if v_metadata_invitation_id <> p_invitation_id::text then
    select exists (
      select 1
      from public.recruiter_invitations as prior_invitation
      where prior_invitation.recruiter_id = v_invitation.recruiter_id
        and prior_invitation.email = v_invitation.email
        and prior_invitation.auth_user_id = p_auth_user_id
        and prior_invitation.status = 'REVOKED'
    ) into v_has_superseded_auth_invitation;
    if not p_is_reissue or not v_has_superseded_auth_invitation then
      raise exception 'The Auth invitation identity does not match the recruiter invitation' using errcode = '23514';
    end if;
  end if;

  update public.recruiter_invitations set status = 'SENT', auth_user_id = p_auth_user_id where id = p_invitation_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (
    v_actor_id,
    case when p_is_reissue then 'recruiter.invitation_reissued' else 'recruiter.invitation_issued' end,
    'recruiter_invitation',
    p_invitation_id,
    jsonb_build_object('expires_at', v_invitation.expires_at)
  );
end;
$$;

create or replace function public.mark_recruiter_invitation_delivery_failed(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(false);
  v_invitation public.recruiter_invitations%rowtype;
begin
  select * into v_invitation from public.recruiter_invitations where id = p_invitation_id for update;
  if not found or v_invitation.status <> 'PREPARED' then
    raise exception 'The invitation cannot be marked as failed' using errcode = '23514';
  end if;
  update public.recruiter_invitations set status = 'DELIVERY_FAILED' where id = p_invitation_id;
  update public.recruiters set invitation_expires_at = null, updated_by = v_actor_id where id = v_invitation.recruiter_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'recruiter.invitation_delivery_failed', 'recruiter_invitation', p_invitation_id, jsonb_build_object('status', 'DELIVERY_FAILED'));
end;
$$;

create or replace function public.revoke_recruiter_invitation(p_invitation_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(false);
  v_invitation public.recruiter_invitations%rowtype;
begin
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 2000 then
    raise exception 'A revocation reason is required' using errcode = '23514';
  end if;
  select * into v_invitation from public.recruiter_invitations where id = p_invitation_id for update;
  if not found or v_invitation.status not in ('PREPARED', 'SENT') then
    raise exception 'Only an active invitation may be revoked' using errcode = '23514';
  end if;
  update public.recruiter_invitations
  set status = 'REVOKED', revoked_at = now(), revoked_by = v_actor_id, revocation_reason = btrim(p_reason)
  where id = p_invitation_id;
  update public.recruiters set invitation_expires_at = null, updated_by = v_actor_id where id = v_invitation.recruiter_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'recruiter.invitation_revoked', 'recruiter_invitation', p_invitation_id, jsonb_build_object('reason', btrim(p_reason)));
end;
$$;

create or replace function public.complete_recruiter_invitation()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_confirmed_at timestamptz;
  v_invitation public.recruiter_invitations%rowtype;
  v_recruiter public.recruiters%rowtype;
begin
  if v_user_id is null then
    raise exception 'An authenticated recruiter is required' using errcode = '42501';
  end if;
  select lower(btrim(user_record.email)), user_record.email_confirmed_at
  into v_email, v_confirmed_at
  from auth.users as user_record
  where user_record.id = v_user_id
  for key share;
  if not found or v_confirmed_at is null then
    raise exception 'A confirmed recruiter email is required' using errcode = '42501';
  end if;

  select * into v_invitation
  from public.recruiter_invitations
  where status = 'SENT' and auth_user_id = v_user_id
  for update;
  if not found or v_invitation.expires_at <= now() or v_invitation.email <> v_email then
    raise exception 'The recruiter invitation is unavailable' using errcode = '42501';
  end if;

  select recruiter.* into v_recruiter
  from public.recruiters as recruiter
  join public.companies as company on company.id = recruiter.company_id
  where recruiter.id = v_invitation.recruiter_id and not recruiter.is_archived and not company.is_archived
  for update of recruiter;
  if not found or v_recruiter.user_id is not null then
    raise exception 'The recruiter contact is unavailable' using errcode = '42501';
  end if;

  perform 1 from public.profiles where id = v_user_id for update;
  if found then
    raise exception 'This Auth user already has a platform profile' using errcode = '42501';
  end if;

  insert into public.profiles (id, display_name, role)
  values (v_user_id, v_recruiter.full_name, 'RECRUITER');
  update public.recruiters set user_id = v_user_id, invitation_expires_at = null, updated_by = v_user_id where id = v_recruiter.id;
  update public.recruiter_invitations set status = 'ACCEPTED', accepted_at = now() where id = v_invitation.id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_user_id, 'recruiter.invitation_accepted', 'recruiter_invitation', v_invitation.id, jsonb_build_object('recruiter_id', v_recruiter.id));
  return v_user_id;
end;
$$;

create or replace function public.grant_recruiter_drive_access(
  p_recruiter_id uuid,
  p_drive_id uuid,
  p_expires_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(false);
  v_existing public.recruiter_drive_access%rowtype;
  v_had_existing boolean := false;
begin
  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'A grant expiry must be in the future' using errcode = '23514';
  end if;
  if not exists (
    select 1
    from public.recruiters as recruiter
    join public.companies as company on company.id = recruiter.company_id
    join public.profiles as profile on profile.id = recruiter.user_id
    join public.placement_drives as drive on drive.id = p_drive_id
    where recruiter.id = p_recruiter_id
      and not recruiter.is_archived
      and not company.is_archived
      and profile.is_active
      and profile.role = 'RECRUITER'::public.app_role
      and drive.company_id = company.id
      and drive.status = 'PUBLISHED'::public.drive_status
  ) then
    raise exception 'An active bound recruiter and published company drive are required' using errcode = '23514';
  end if;

  select * into v_existing from public.recruiter_drive_access
  where recruiter_id = p_recruiter_id and drive_id = p_drive_id for update;
  v_had_existing := found;
  if found then
    update public.recruiter_drive_access
    set expires_at = p_expires_at, granted_by = v_actor_id, can_view_applicants = false, can_view_resumes = false,
        revoked_at = null, revoked_by = null, revocation_reason = null
    where recruiter_id = p_recruiter_id and drive_id = p_drive_id;
  else
    insert into public.recruiter_drive_access (recruiter_id, drive_id, expires_at, granted_by)
    values (p_recruiter_id, p_drive_id, p_expires_at, v_actor_id);
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (
    v_actor_id,
    'recruiter.drive_granted',
    'recruiter_drive_access',
    p_drive_id,
    case when v_had_existing then jsonb_build_object('revoked_at', v_existing.revoked_at, 'expires_at', v_existing.expires_at) else null end,
    jsonb_build_object('recruiter_id', p_recruiter_id, 'expires_at', p_expires_at)
  );
end;
$$;

create or replace function public.revoke_recruiter_drive_access(
  p_recruiter_id uuid,
  p_drive_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_phase6_staff(false);
  v_access public.recruiter_drive_access%rowtype;
begin
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 2000 then
    raise exception 'A revocation reason is required' using errcode = '23514';
  end if;
  select * into v_access from public.recruiter_drive_access
  where recruiter_id = p_recruiter_id and drive_id = p_drive_id for update;
  if not found or v_access.revoked_at is not null then
    raise exception 'Only an active recruiter drive grant may be revoked' using errcode = '23514';
  end if;
  update public.recruiter_drive_access
  set revoked_at = now(), revoked_by = v_actor_id, revocation_reason = btrim(p_reason)
  where recruiter_id = p_recruiter_id and drive_id = p_drive_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (
    v_actor_id,
    'recruiter.drive_revoked',
    'recruiter_drive_access',
    p_drive_id,
    jsonb_build_object('recruiter_id', p_recruiter_id, 'expires_at', v_access.expires_at),
    jsonb_build_object('recruiter_id', p_recruiter_id, 'reason', btrim(p_reason))
  );
end;
$$;

-- The existing hook remains the only Auth-user creation hook. It permits either
-- the Phase 4 roster path or a matching PREPARED recruiter invitation.
create or replace function public.enforce_student_roster_signup(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(coalesce(event -> 'user' ->> 'email', '')));
  v_invitation_id uuid;
begin
  if v_email <> '' and exists (
    select 1
    from public.student_roster as roster
    where roster.institutional_email = v_email
      and roster.is_active
      and not exists (
        select 1 from public.student_profiles as student_profile where student_profile.roster_id = roster.id
      )
  ) then
    return '{}'::jsonb;
  end if;

  begin
    v_invitation_id := nullif(event -> 'user' -> 'user_metadata' ->> 'recruiter_invitation_id', '')::uuid;
  exception when invalid_text_representation then
    v_invitation_id := null;
  end;
  if v_invitation_id is not null and exists (
    select 1
    from public.recruiter_invitations as invitation
    join public.recruiters as recruiter on recruiter.id = invitation.recruiter_id
    join public.companies as company on company.id = recruiter.company_id
    where invitation.id = v_invitation_id
      and invitation.status = 'PREPARED'
      and invitation.email = v_email
      and invitation.expires_at > now()
      and not recruiter.is_archived
      and not company.is_archived
  ) then
    return '{}'::jsonb;
  end if;

  return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', 'Registration is unavailable for this account.'));
end;
$$;

revoke select on public.student_roster, public.student_profiles from supabase_auth_admin;
grant usage on schema public to supabase_auth_admin;
grant execute on function public.enforce_student_roster_signup(jsonb) to supabase_auth_admin;
revoke all on function public.enforce_student_roster_signup(jsonb) from public, anon, authenticated;

alter table public.recruiter_invitations enable row level security;

grant select (id, name, normalized_name, website_url, description, is_archived, archived_at) on public.companies to authenticated;
grant select (id, company_id, user_id, full_name, email, phone_number, invitation_expires_at, is_archived, archived_at) on public.recruiters to authenticated;
grant select (id, recruiter_id, status, issued_at, expires_at, accepted_at, revoked_at, revocation_reason) on public.recruiter_invitations to authenticated;
grant select (id, company_id, title, drive_type, location, application_deadline, status) on public.placement_drives to authenticated;
grant select (recruiter_id, drive_id, expires_at, revoked_at) on public.recruiter_drive_access to authenticated;

create policy "phase 6 staff can read companies"
on public.companies for select to authenticated
using ((select private.is_phase6_staff()));
create policy "recruiters can read their assigned company"
on public.companies for select to authenticated
using ((select private.can_read_recruiter_company(id)));

create policy "phase 6 staff can read recruiters"
on public.recruiters for select to authenticated
using ((select private.is_phase6_staff()));
create policy "recruiters can read their own contact"
on public.recruiters for select to authenticated
using (id = (select private.current_active_recruiter_id()));

create policy "phase 6 managers can read recruiter invitations"
on public.recruiter_invitations for select to authenticated
using ((select private.is_phase6_manager()));

create policy "phase 6 managers can read published drives for grants"
on public.placement_drives for select to authenticated
using (
  (select private.is_phase6_manager())
  and status = 'PUBLISHED'::public.drive_status
);
create policy "recruiters can read granted published drives"
on public.placement_drives for select to authenticated
using ((select private.can_read_recruiter_published_drive(id)));

create policy "phase 6 managers can read recruiter drive grants"
on public.recruiter_drive_access for select to authenticated
using ((select private.is_phase6_manager()));
create policy "recruiters can read active own drive grants"
on public.recruiter_drive_access for select to authenticated
using (
  recruiter_id = (select private.current_active_recruiter_id())
  and revoked_at is null
  and (expires_at is null or expires_at > now())
);

revoke all on function public.create_company(text, text, text) from public, anon;
revoke all on function public.update_company(uuid, text, text, text) from public, anon;
revoke all on function public.set_company_archive_state(uuid, boolean) from public, anon;
revoke all on function public.create_recruiter_contact(uuid, text, text, text) from public, anon;
revoke all on function public.update_recruiter_contact(uuid, text, text, text) from public, anon;
revoke all on function public.set_recruiter_archive_state(uuid, boolean) from public, anon;
revoke all on function public.prepare_recruiter_invitation(uuid, boolean) from public, anon;
revoke all on function public.mark_recruiter_invitation_sent(uuid, uuid, boolean) from public, anon;
revoke all on function public.mark_recruiter_invitation_delivery_failed(uuid) from public, anon;
revoke all on function public.revoke_recruiter_invitation(uuid, text) from public, anon;
revoke all on function public.complete_recruiter_invitation() from public, anon;
revoke all on function public.grant_recruiter_drive_access(uuid, uuid, timestamptz) from public, anon;
revoke all on function public.revoke_recruiter_drive_access(uuid, uuid, text) from public, anon;
grant execute on function public.create_company(text, text, text) to authenticated;
grant execute on function public.update_company(uuid, text, text, text) to authenticated;
grant execute on function public.set_company_archive_state(uuid, boolean) to authenticated;
grant execute on function public.create_recruiter_contact(uuid, text, text, text) to authenticated;
grant execute on function public.update_recruiter_contact(uuid, text, text, text) to authenticated;
grant execute on function public.set_recruiter_archive_state(uuid, boolean) to authenticated;
grant execute on function public.prepare_recruiter_invitation(uuid, boolean) to authenticated;
grant execute on function public.mark_recruiter_invitation_sent(uuid, uuid, boolean) to authenticated;
grant execute on function public.mark_recruiter_invitation_delivery_failed(uuid) to authenticated;
grant execute on function public.revoke_recruiter_invitation(uuid, text) to authenticated;
grant execute on function public.complete_recruiter_invitation() to authenticated;
grant execute on function public.grant_recruiter_drive_access(uuid, uuid, timestamptz) to authenticated;
grant execute on function public.revoke_recruiter_drive_access(uuid, uuid, text) to authenticated;

comment on table public.recruiter_invitations is
  'Phase 6 invitation lifecycle. Supabase Auth retains the invite secret; this table never stores links, tokens, OTPs, verifier hashes, or raw provider errors.';
