-- Phase 5: commit the enum value separately before using it in constraints,
-- functions, or policies in the subsequent migration.
alter type public.document_kind add value if not exists 'SKILL_EVIDENCE';
