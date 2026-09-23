-- Reactivation is deliberately separate from archival so the transition remains
-- audited and an archived catalog record retains its historical associations.
create or replace function public.reactivate_skill_catalog_entry(p_skill_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null or not private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]) then
    raise exception 'Only the TNP Secretary or Super Admin may manage the skill catalog' using errcode = '42501';
  end if;

  update public.skills
  set is_archived = false,
      archived_at = null,
      archived_by = null,
      updated_by = v_actor_id
  where id = p_skill_id and is_archived;
  if not found then
    raise exception 'An archived skill catalog entry is required' using errcode = 'P0002';
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'skill.catalog_reactivated', 'skill', p_skill_id, jsonb_build_object('is_archived', false));
end;
$$;

revoke all on function public.reactivate_skill_catalog_entry(uuid) from public, anon, authenticated;
grant execute on function public.reactivate_skill_catalog_entry(uuid) to authenticated;

comment on function public.reactivate_skill_catalog_entry(uuid) is
  'Phase 5 audited catalog reactivation; historical student skill records remain intact.';
