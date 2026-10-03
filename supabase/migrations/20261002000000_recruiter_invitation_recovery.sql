-- Phase 6 completion: recover Auth success followed by database finalization
-- failure without trusting caller reissue flags or arbitrary user metadata.
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
  v_auth_user auth.users%rowtype;
  v_is_reissue boolean;
begin
  if p_is_reissue is null then
    raise exception 'An explicit invitation operation is required' using errcode = '23514';
  end if;
  select * into v_invitation
  from public.recruiter_invitations where id = p_invitation_id for update;
  if not found or v_invitation.status <> 'PREPARED' or v_invitation.expires_at <= now() then
    raise exception 'The invitation is no longer ready to send' using errcode = '23514';
  end if;

  if not exists (
    select 1 from public.recruiters as recruiter
    join public.companies as company on company.id = recruiter.company_id
    where recruiter.id = v_invitation.recruiter_id
      and recruiter.email = v_invitation.email
      and recruiter.user_id is null
      and not recruiter.is_archived and not company.is_archived
  ) then
    raise exception 'The recruiter contact is unavailable' using errcode = '23514';
  end if;

  select * into v_auth_user from auth.users where id = p_auth_user_id for key share;
  if not found or lower(btrim(v_auth_user.email)) is distinct from v_invitation.email
    or exists (select 1 from public.profiles where id = p_auth_user_id)
    or exists (select 1 from public.recruiters where user_id = p_auth_user_id) then
    raise exception 'The Auth invitation identity does not match the recruiter invitation' using errcode = '23514';
  end if;

  if not (
    coalesce(v_auth_user.raw_user_meta_data ->> 'recruiter_invitation_id' = p_invitation_id::text, false)
    and v_auth_user.invited_at is not null
    and v_auth_user.created_at is not null
    and v_auth_user.created_at >= v_invitation.issued_at
    and v_auth_user.created_at <= v_invitation.expires_at
  ) then
    if not exists (
      select 1 from public.recruiter_invitations as prior
      where prior.id::text = v_auth_user.raw_user_meta_data ->> 'recruiter_invitation_id'
        and prior.recruiter_id = v_invitation.recruiter_id
        and prior.email = v_invitation.email
        and prior.status in ('REVOKED', 'DELIVERY_FAILED')
        and (
          prior.auth_user_id = p_auth_user_id
          or (
            -- Finalization never recorded the user ID. Auth-owned creation and
            -- invite timestamps prove this still-unconfirmed user was created
            -- during the exact prior prepared invitation's valid window.
            prior.auth_user_id is null
            and v_auth_user.email_confirmed_at is null
            and v_auth_user.invited_at is not null
            and v_auth_user.created_at >= prior.issued_at
            and v_auth_user.created_at <= prior.expires_at
          )
        )
    ) then
      raise exception 'The Auth invitation identity does not match the recruiter invitation' using errcode = '23514';
    end if;
  end if;

  -- Keep the existing RPC signature for compatibility, but classify the audit
  -- from persisted lifecycle history, never p_is_reissue supplied by a caller.
  select exists (
    select 1 from public.recruiter_invitations
    where recruiter_id = v_invitation.recruiter_id and id <> v_invitation.id
  ) into v_is_reissue;

  update public.recruiter_invitations
  set status = 'SENT', auth_user_id = p_auth_user_id where id = p_invitation_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (
    v_actor_id,
    case when v_is_reissue then 'recruiter.invitation_reissued' else 'recruiter.invitation_issued' end,
    'recruiter_invitation', p_invitation_id,
    jsonb_build_object('expires_at', v_invitation.expires_at)
  );
end;
$$;

revoke all on function public.mark_recruiter_invitation_sent(uuid, uuid, boolean) from public, anon;
grant execute on function public.mark_recruiter_invitation_sent(uuid, uuid, boolean) to authenticated;
