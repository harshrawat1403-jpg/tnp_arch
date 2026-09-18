# Phase 3 Super Admin bootstrap

This is a one-time protected operator procedure, not an application route, registration flow, or public RPC. Run it only in an isolated environment after the Technical Secretary's identity has been verified and an authenticated Supabase user has been created through the provider's protected operator interface.

Do not run this against production without the institution's approved change/recovery process. Never put a service-role key, database password, or user password in source control, terminal transcripts, issue comments, or browser code.

1. Record the verified Auth user UUID as `VERIFIED_AUTH_USER_UUID`; it must already exist in `auth.users`.
2. In the protected SQL operator environment, start one transaction.
3. Insert the matching profile and immutable bootstrap audit event. Replace only the angle-bracket placeholders; do not quote an email address or use a browser-provided role.

```sql
begin;

insert into public.profiles (id, display_name, role, coordinator_slot)
values (
  '<VERIFIED_AUTH_USER_UUID>',
  '<VERIFIED_TECHNICAL_SECRETARY_NAME>',
  'SUPER_ADMIN',
  null
);

insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
values (
  '<VERIFIED_AUTH_USER_UUID>',
  'auth.super_admin_bootstrap',
  'profile',
  '<VERIFIED_AUTH_USER_UUID>',
  jsonb_build_object('role', 'SUPER_ADMIN')
);

set constraints profiles_require_exactly_one_active_super_admin immediate;
commit;
```

4. Verify exactly one active Super Admin exists and that the audit event is present.
5. Test sign-in and `/account` with the provisioned user in that isolated environment.

The Phase 2 deferred constraint rejects a missing or second active Super Admin. Do not deactivate/delete the sole Super Admin. Later role changes require an approved, atomic, audited Super Admin operation; no role-assignment UI or public role RPC exists in Phase 3.
