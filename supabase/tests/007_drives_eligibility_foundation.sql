begin;
select no_plan();

insert into auth.users(id,email,email_confirmed_at) select
  ('71000000-0000-0000-0000-' || lpad(n::text,12,'0'))::uuid,'phase7-'||n||'@example.test',now()
from generate_series(1,8) n;
insert into public.profiles(id,display_name,role,coordinator_slot) values
 ('71000000-0000-0000-0000-000000000001','P7 Super','SUPER_ADMIN',null),
 ('71000000-0000-0000-0000-000000000002','P7 Secretary','TNP_SECRETARY',null),
 ('71000000-0000-0000-0000-000000000003','P7 Coordinator 1','TNP_COORDINATOR',1),
 ('71000000-0000-0000-0000-000000000004','P7 Coordinator 2','TNP_COORDINATOR',2),
 ('71000000-0000-0000-0000-000000000005','P7 Student','STUDENT',null),
 ('71000000-0000-0000-0000-000000000006','P7 Pending','STUDENT',null),
 ('71000000-0000-0000-0000-000000000007','P7 Missing','STUDENT',null),
 ('71000000-0000-0000-0000-000000000008','P7 Recruiter','RECRUITER',null);
insert into public.student_roster(id,institutional_email,student_identifier,course,batch_year)
select ('72000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'phase7-'||n||'@example.test','P7-'||n,'B.Arch',2027
from generate_series(5,7) n;
insert into public.student_profiles(user_id,roster_id)
select ('71000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,('72000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid
from generate_series(5,7) n;
insert into public.academic_records(student_id,course,batch_year,cgpa,active_backlog_count,verification_status,verified_at,verified_by)
values ('71000000-0000-0000-0000-000000000005','B.Arch',2027,8,0,'VERIFIED',now(),'71000000-0000-0000-0000-000000000002'),
 ('71000000-0000-0000-0000-000000000006','B.Arch',2027,1,10,'PENDING',null,null);
insert into public.companies(id,name,created_by,updated_by) values
 ('73000000-0000-0000-0000-000000000001','Phase7 Active','71000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002'),
 ('73000000-0000-0000-0000-000000000002','Phase7 Other','71000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002');
create function pg_temp.content() returns jsonb language sql as $$
 select jsonb_build_object('company_id','73000000-0000-0000-0000-000000000001','title','Phase7 Test',
 'drive_type','PLACEMENT','description','A bounded placement opportunity','application_deadline',now()+interval '7 days',
 'location','Pune','package_lpa',6,'stipend_monthly',null,'compensation_details','Annual package',
 'minimum_cgpa',7,'maximum_active_backlogs',0,'exclude_previously_selected_placement',false,
 'informational_requirements','Skills are informational, not eligibility gates',
 'eligible_pairs',jsonb_build_array(jsonb_build_object('course','B.Arch','batch_year',2027)));
$$;
insert into public.placement_drives(id,company_id,title,drive_type,description,application_deadline,created_by)
select ('74000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'73000000-0000-0000-0000-000000000001',
 'Drive '||n,case when n=4 then 'INTERNSHIP'::public.drive_type else 'PLACEMENT'::public.drive_type end,
 'Phase7 fixture',now()+interval '7 days','71000000-0000-0000-0000-000000000003'
from generate_series(1,4) n;
insert into public.drive_eligibility(drive_id,minimum_cgpa)
select id,7 from public.placement_drives;
insert into public.drive_eligible_batches(drive_id,course,batch_year)
select id,'B.Arch',2027 from public.placement_drives;

select ok(not has_table_privilege('authenticated','public.placement_drives','UPDATE'),'no direct authenticated drive mutations');
select ok(not has_column_privilege('authenticated','public.placement_drives','description','SELECT'),'recruiter column grants are not broadened');
select ok(not has_column_privilege('authenticated','public.placement_drives','package_lpa','SELECT'),'compensation not granted on base table');
select ok(not has_table_privilege('authenticated','public.drive_eligibility','SELECT'),'criteria remain RPC-only');
select ok(not has_function_privilege('authenticated','private.calculate_drive_eligibility(jsonb,jsonb,timestamptz)','EXECUTE'),'private evaluator is not an RPC');
select ok(not has_function_privilege('anon','public.student_drive_list(integer,public.drive_type)','EXECUTE'),'anonymous list denied');
select ok(not has_function_privilege('authenticated','public.transition_application_status(uuid,uuid,public.application_status,text,boolean)','EXECUTE'),'application mutations remain unavailable');

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.save_drive_draft(pg_temp.content())$$,'coordinator creates draft with atomic criteria');
select lives_ok($$select public.save_drive_draft(pg_temp.content(),'74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int)$$,'coordinator edits draft');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.save_drive_draft(pg_temp.content(),'74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int)$$,'other coordinator can edit any draft');
select throws_ok($$select public.transition_drive('74000000-0000-0000-0000-000000000001',5,'PUBLISHED')$$,'42501',null,'coordinator cannot publish');
select throws_ok($$select public.correct_published_drive('74000000-0000-0000-0000-000000000001',5,pg_temp.content(),'Reason','Notice')$$,'42501',null,'coordinator cannot correct published content');
select throws_ok($$select public.save_drive_draft(pg_temp.content()||'{"eligible_pairs":[]}'::jsonb)$$,'23514',null,'empty pairs rejected');
select throws_ok($$select public.save_drive_draft(pg_temp.content()||'{"eligible_pairs":[{"course":"B.Arch","batch_year":2027},{"course":" B.Arch ","batch_year":2027}]}'::jsonb)$$,'23514',null,'normalized duplicate pairs rejected');
select throws_ok($$select public.save_drive_draft(pg_temp.content()||'{"minimum_cgpa":null}'::jsonb)$$,'23514',null,'nullable thresholds rejected');
select throws_ok($$select public.save_drive_draft(pg_temp.content()||'{"maximum_active_backlogs":51}'::jsonb)$$,'23514',null,'backlog bounds enforced');
select throws_ok($$select public.save_drive_draft(pg_temp.content()||'{"student_id":"71000000-0000-0000-0000-000000000005"}'::jsonb)$$,'23514',null,'unapproved content keys rejected');
select throws_ok($$select public.save_drive_draft(pg_temp.content()||'{"title":{"unexpected":"object"}}'::jsonb)$$,'23514',null,'canonical text fields reject object transport');
select throws_ok($$select public.save_drive_draft(pg_temp.content()||'{"location":42}'::jsonb)$$,'23514',null,'optional text fields reject numeric transport');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.transition_drive('74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int,'PUBLISHED')$$,'Secretary publishes valid draft');
select lives_ok($$select public.transition_drive('74000000-0000-0000-0000-000000000002',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000002')->>'revision')::int,'PUBLISHED')$$,'second valid drive publishes');
select throws_ok($$select public.set_company_archive_state('73000000-0000-0000-0000-000000000001',true)$$,'23514',null,'published drive blocks company archive');
select throws_ok($$select public.save_drive_draft(pg_temp.content(),'74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int)$$,'23514',null,'published drive cannot use draft edit');
select throws_ok($$select public.correct_published_drive('74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int,pg_temp.content(),'','Notice')$$,'23514',null,'internal reason mandatory');
select throws_ok($$select public.correct_published_drive('74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int,pg_temp.content(),'Reason','')$$,'23514',null,'student notice mandatory');
select throws_ok($$select public.correct_published_drive('74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int,pg_temp.content()||'{"company_id":"73000000-0000-0000-0000-000000000002"}','Reason','Notice')$$,'23514',null,'published company immutable');
select throws_ok($$select public.correct_published_drive('74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int,pg_temp.content()||'{"drive_type":"INTERNSHIP"}','Reason','Notice')$$,'23514',null,'published type immutable');
reset role;
create temporary table before_stale as select revision,(select count(*) from public.audit_logs) audits
from public.placement_drives where id='74000000-0000-0000-0000-000000000001';
set local role authenticated;
select throws_ok($$select public.correct_published_drive('74000000-0000-0000-0000-000000000001',1,pg_temp.content(),'Reason','Notice')$$,'40001',null,'stale correction denied');
reset role;
select is((select revision from public.placement_drives where id='74000000-0000-0000-0000-000000000001'),(select revision from before_stale),'stale correction leaves revision unchanged');
select is((select count(*) from public.audit_logs),(select audits from before_stale),'stale correction leaves audit unchanged');
set local role authenticated;
select lives_ok($$select public.correct_published_drive('74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int,pg_temp.content()||'{"title":"Corrected opportunity","minimum_cgpa":8}','Typo and threshold correction','Please review the corrected criteria.')$$,'published correction is atomic');
reset role;
select is((select revision from public.placement_drives where id='74000000-0000-0000-0000-000000000001'),(select revision+1 from before_stale),'multi-row correction increments revision exactly once');
select ok(exists(select 1 from public.audit_logs where action='drive.updated' and after_data->>'classification'='published/material'),'published correction classified and audited');
select ok(exists(select 1 from public.audit_logs where action='drive.eligibility_updated' and after_data->>'reason'='Typo and threshold correction'),'criteria correction separately audited');
set local role authenticated;
select throws_ok($$select public.correct_published_drive('74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int,
 pg_temp.content()||jsonb_build_object('application_deadline',now()-interval '1 hour'),'Bad deadline','Bad deadline')$$,'23514',null,'pre-expiry replacement must still be in the future');
select lives_ok($$select public.correct_published_drive('74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int,
 pg_temp.content()||jsonb_build_object('minimum_cgpa',8,'application_deadline',now()+interval '8 days'),'Extend while still open','Deadline extended before expiry.')$$,'future deadline replacement permitted before expiry');

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000001')->'eligibility'->>'academic_result','PASS','verified academic threshold equality passes');
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000001')->'eligibility'->>'is_eligible','true','overall pending profile, no skills or resume do not gate eligibility');
select ok(public.student_drive_detail('74000000-0000-0000-0000-000000000003') is null,'draft hidden with generic null');
select ok(public.student_drive_detail('ffffffff-ffff-ffff-ffff-ffffffffffff') is null,'nonexistent drive same generic null');
select ok(not (public.student_drive_detail('74000000-0000-0000-0000-000000000001') ?| array['created_by','updated_by','reason','student_id','applications']),'student projection excludes internal/private data');
select throws_ok($$select public.staff_drive_list()$$,'42501',null,'student cannot read staff list');
select throws_ok($$select public.save_drive_draft(pg_temp.content())$$,'42501',null,'student cannot mutate drives');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000006',true);
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000001')->'eligibility'->>'academic_result','UNDETERMINED','pending academics undetermined');
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000001')->'eligibility'->'reason_codes','["ACADEMIC_UNVERIFIED"]'::jsonb,'unverified numbers are never compared');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000007',true);
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000001')->'eligibility'->'reason_codes','["ACADEMIC_DATA_UNAVAILABLE"]'::jsonb,'missing academics fail closed without numeric comparisons');
reset role;
-- Private core can be tested at an exact instant without exposing client time input.
select is(private.calculate_drive_eligibility(private.drive_projection('74000000-0000-0000-0000-000000000001'),
 '{"course":"B.Arch","batch_year":2027,"has_academics":true,"academic_verified":true,"cgpa":8,"backlogs":0,"selected_placement":false}',
 (select application_deadline from public.placement_drives where id='74000000-0000-0000-0000-000000000001'))->'reason_codes','["DEADLINE_PASSED"]'::jsonb,'exact deadline is not open');
select is(private.calculate_drive_eligibility(private.drive_projection('74000000-0000-0000-0000-000000000001'),
 '{"course":"B.Arch","batch_year":2028,"has_academics":true,"academic_verified":true,"cgpa":6,"backlogs":1,"selected_placement":false}',now())->'reason_codes',
 '["BATCH_NOT_ELIGIBLE","CGPA_BELOW_MINIMUM","ACTIVE_BACKLOG_LIMIT_EXCEEDED"]'::jsonb,'ordered exact-pair and numerical failures');
select is(private.calculate_drive_eligibility(private.drive_projection('74000000-0000-0000-0000-000000000001'),
 '{"course":"BIM","batch_year":2027,"has_academics":true,"academic_verified":true,"cgpa":8,"backlogs":0,"selected_placement":false}',now())->'reason_codes',
 '["COURSE_NOT_ELIGIBLE"]'::jsonb,'missing course differs from missing batch');
select is(private.calculate_drive_eligibility(private.drive_projection('74000000-0000-0000-0000-000000000001')||'{"eligible_pairs":[{"course":"B.Arch","batch_year":2026},{"course":"BIM","batch_year":2027}]}',
 '{"course":"B.Arch","batch_year":2027,"has_academics":true,"academic_verified":true,"cgpa":8,"backlogs":0,"selected_placement":false}',now())->'reason_codes',
 '["BATCH_NOT_ELIGIBLE"]'::jsonb,'pairs are not interpreted as an independent cross product');
select is(private.calculate_drive_eligibility(private.drive_projection('74000000-0000-0000-0000-000000000001')||'{"minimum_cgpa":null}',
 '{"course":"B.Arch","batch_year":2027,"has_academics":false,"academic_verified":false,"selected_placement":false}',
 (select application_deadline from public.placement_drives where id='74000000-0000-0000-0000-000000000001'))->'reason_codes',
 '["DEADLINE_PASSED","DRIVE_CRITERIA_UNAVAILABLE","ACADEMIC_DATA_UNAVAILABLE"]'::jsonb,'availability then criteria then academic readiness reasons');
select is(private.calculate_drive_eligibility(private.drive_projection('74000000-0000-0000-0000-000000000001')||'{"eligible_pairs":[]}',
 '{"course":"B.Arch","batch_year":2027,"has_academics":true,"academic_verified":true,"cgpa":8,"backlogs":0,"selected_placement":false}',now())->'reason_codes',
 '["DRIVE_CRITERIA_UNAVAILABLE"]'::jsonb,'missing configured pairs do not invent a course rejection');

-- Existing terminal correction primitive is operator-only, not a Phase 8 API.
insert into public.applications(id,student_id,drive_id,submitted_by) values
 ('75000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000005','74000000-0000-0000-0000-000000000004','71000000-0000-0000-0000-000000000005');
select public.transition_application_status('75000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002','SHORTLISTED',null,false);
select public.transition_application_status('75000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002','INTERVIEW',null,false);
select public.transition_application_status('75000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002','SELECTED',null,false);
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select public.correct_published_drive('74000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000001')->>'revision')::int,pg_temp.content()||'{"exclude_previously_selected_placement":true}','Policy enabled','Prior placement selection is now excluded.');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000001')->'eligibility'->>'is_eligible','true','selected internship does not exclude placement');
reset role;
insert into public.applications(id,student_id,drive_id,submitted_by) values
 ('75000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000005','74000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000005');
select public.transition_application_status('75000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','SHORTLISTED',null,false);
select public.transition_application_status('75000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','INTERVIEW',null,false);
select public.transition_application_status('75000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','SELECTED',null,false);
set local role authenticated;
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000001')->'eligibility'->'reason_codes','["PREVIOUSLY_SELECTED_PLACEMENT"]'::jsonb,'current selected placement excludes only with flag');
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000002')->'eligibility'->>'is_eligible','true','flag false ignores selection');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select public.save_drive_draft(pg_temp.content()||'{"drive_type":"INTERNSHIP","exclude_previously_selected_placement":true}',
 '74000000-0000-0000-0000-000000000004',(public.staff_drive_detail('74000000-0000-0000-0000-000000000004')->>'revision')::int);
select public.transition_drive('74000000-0000-0000-0000-000000000004',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000004')->>'revision')::int,'PUBLISHED');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000004')->'eligibility'->'reason_codes',
 '["PREVIOUSLY_SELECTED_PLACEMENT"]'::jsonb,'current selected placement also excludes an internship target when its flag is enabled');
reset role;
select public.transition_application_status('75000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','INTERVIEW','Correct erroneous selection',true);
set local role authenticated;
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000001')->'eligibility'->>'is_eligible','true','audited terminal correction restores current eligibility, not ever-selected history');
select is(public.student_drive_detail('74000000-0000-0000-0000-000000000004')->'eligibility'->>'is_eligible','true','terminal correction also restores internship eligibility');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select public.transition_drive('74000000-0000-0000-0000-000000000004',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000004')->>'revision')::int,'CLOSED');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);

reset role;
-- More than one page, intentionally tied deadlines; SQL type filter before paging.
insert into public.placement_drives(id,company_id,title,drive_type,description,application_deadline)
select ('76000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'73000000-0000-0000-0000-000000000001',
 'Pagination '||n,'INTERNSHIP','Pagination fixture',now()+interval '10 days' from generate_series(1,25) n;
insert into public.drive_eligibility(drive_id) select id from public.placement_drives where title like 'Pagination %';
insert into public.drive_eligible_batches(drive_id,course,batch_year) select id,'B.Arch',2027 from public.placement_drives where title like 'Pagination %';
update public.placement_drives set status='PUBLISHED',published_at=now() where title like 'Pagination %';
set local role authenticated;
select is(jsonb_array_length(public.student_drive_list(1,'INTERNSHIP')),21,'first filtered page returns twenty plus lookahead');
select is(jsonb_array_length(public.student_drive_list(2,'INTERNSHIP')),5,'second filtered page has remaining five');
select is((select count(distinct x->'eligibility'->>'evaluated_at') from jsonb_array_elements(public.student_drive_list(1,'INTERNSHIP')) x),1::bigint,'all page eligibility results share one database timestamp');
select is(public.student_drive_list(1,'INTERNSHIP')->0->>'id','76000000-0000-0000-0000-000000000001','ties use stable ascending ID');
select ok(not exists(select 1 from jsonb_array_elements(public.student_drive_list(1,'INTERNSHIP')) with ordinality a(v,n)
 join jsonb_array_elements(public.student_drive_list(2,'INTERNSHIP')) b(v) on a.v->>'id'=b.v->>'id' where a.n<=20),'adjacent visible pages distinct');
select is(public.student_drive_list(-1,'INTERNSHIP'),public.student_drive_list(1,'INTERNSHIP'),'negative pages clamp');
select is(public.student_drive_list(2147483647,'INTERNSHIP'),'[]'::jsonb,'extreme pages bounded safely');
select ok(not (public.student_drive_list()->0 ? 'description'),'list avoids rich detail payload');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000008',true);
select throws_ok($$select public.student_drive_list()$$,'42501',null,'recruiter cannot evaluate student eligibility');
select throws_ok($$select public.student_drive_detail('74000000-0000-0000-0000-000000000001')$$,'42501',null,'recruiter cannot use rich student detail');
select throws_ok($$select public.staff_drive_detail('74000000-0000-0000-0000-000000000001')$$,'42501',null,'recruiter cannot use staff detail');
select throws_ok($$select public.transition_drive('74000000-0000-0000-0000-000000000001',1,'CLOSED')$$,'42501',null,'recruiter cannot mutate lifecycle');
select throws_ok($$select description from public.placement_drives$$,'42501',null,'recruiter cannot bypass projection');
reset role;

-- Expired PUBLISHED remains visible. Operator fixture predates its deadline.
insert into public.placement_drives(id,company_id,title,drive_type,description,created_at,application_deadline)
values ('77000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Expired fixture','PLACEMENT','Expired fixture',now()-interval '2 days',now()-interval '1 day');
insert into public.drive_eligibility(drive_id) values ('77000000-0000-0000-0000-000000000001');
insert into public.drive_eligible_batches(drive_id,course,batch_year) values ('77000000-0000-0000-0000-000000000001','B.Arch',2027);
-- Simulate lawful publication yesterday using a transaction-local trigger disable
-- in this operator-owned test only; no application bypass exists.
alter table public.placement_drives disable trigger drives_content_integrity;
update public.placement_drives set status='PUBLISHED',published_at=created_at where id='77000000-0000-0000-0000-000000000001';
alter table public.placement_drives enable trigger drives_content_integrity;
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
select is(public.student_drive_detail('77000000-0000-0000-0000-000000000001')->'eligibility'->'reason_codes','["DEADLINE_PASSED"]'::jsonb,'expired published remains visible without auto closure');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.correct_published_drive('77000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('77000000-0000-0000-0000-000000000001')->>'revision')::int,pg_temp.content(),'Extend','Extended')$$,'23514',null,'expired published drive cannot be extended');
select lives_ok($$select public.correct_published_drive('77000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('77000000-0000-0000-0000-000000000001')->>'revision')::int,
 pg_temp.content()||jsonb_build_object('application_deadline',public.staff_drive_detail('77000000-0000-0000-0000-000000000001')->>'application_deadline'),'Correct title','Title corrected; deadline unchanged')$$,'Super Admin can correct other expired content with reason/notice');
select lives_ok($$select public.transition_drive('77000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('77000000-0000-0000-0000-000000000001')->>'revision')::int,'CLOSED')$$,'explicit closure permitted after expiry');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
select ok(public.student_drive_detail('77000000-0000-0000-0000-000000000001') is null,'closed same generic hidden result');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.transition_drive('77000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('77000000-0000-0000-0000-000000000001')->>'revision')::int,'PUBLISHED')$$,'23514',null,'closed never reopens');
select lives_ok($$select public.transition_drive('77000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('77000000-0000-0000-0000-000000000001')->>'revision')::int,'ARCHIVED')$$,'closed to archived terminal transition');
select throws_ok($$select public.transition_drive('77000000-0000-0000-0000-000000000001',
 (public.staff_drive_detail('77000000-0000-0000-0000-000000000001')->>'revision')::int,'DRAFT')$$,'23514',null,'archived never unarchives');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
select ok(public.student_drive_detail('77000000-0000-0000-0000-000000000001') is null,'archived same generic hidden result');
reset role;
select is((select last_material_change_notice from public.placement_drives where id='77000000-0000-0000-0000-000000000001'),'Title corrected; deadline unchanged','notice preserved through close/archive');
select throws_ok($$update public.placement_drives set title='Illegal' where id='77000000-0000-0000-0000-000000000001'$$,'23514',null,'archived content locked even to privileged SQL');
select throws_ok($$update public.drive_eligibility set minimum_cgpa=1 where drive_id='77000000-0000-0000-0000-000000000001'$$,'42501',null,'archived criteria locked');
select throws_ok($$delete from public.drive_eligible_batches where drive_id='77000000-0000-0000-0000-000000000001'$$,'42501',null,'archived pairs locked');
select throws_ok($$update public.placement_drives set title='Illegal' where id='74000000-0000-0000-0000-000000000001'$$,'42501',null,'published direct SQL edits locked');
select ok(not exists(select 1 from public.audit_logs where action like 'drive.%' and
 (after_data ?| array['cgpa','backlogs','student_id','token','signed_url','service_role'])),'Phase7 audit omits student academic values and secrets');

select throws_ok($$delete from public.placement_drives where id='74000000-0000-0000-0000-000000000003'$$,'42501',null,'draft deletion denied even to privileged SQL');
select throws_ok($$update public.placement_drives set status='ARCHIVED',published_at=null,closed_at=null,
 archived_at=now(),archived_by='71000000-0000-0000-0000-000000000001'
 where id='74000000-0000-0000-0000-000000000003'$$,'23514',null,'draft cannot skip directly to archive');
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select public.set_company_archive_state('73000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.save_drive_draft(pg_temp.content()||'{"company_id":"73000000-0000-0000-0000-000000000002"}')$$,'23514',null,'archived company cannot receive new draft');
select throws_ok($$select public.save_drive_draft(pg_temp.content()||'{"minimum_cgpa":7.123}')$$,'23514',null,'threshold cannot silently round');
reset role;
delete from public.drive_eligible_batches where drive_id='74000000-0000-0000-0000-000000000003';
set local role authenticated;
select throws_ok($$select public.transition_drive('74000000-0000-0000-0000-000000000003',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000003')->>'revision')::int,'PUBLISHED')$$,'23514',null,'publication without cohort pairs denied');
reset role;
insert into public.drive_eligible_batches(drive_id,course,batch_year) values ('74000000-0000-0000-0000-000000000003','B.Arch',2027);
delete from public.drive_eligibility where drive_id='74000000-0000-0000-0000-000000000003';
set local role authenticated;
select throws_ok($$select public.transition_drive('74000000-0000-0000-0000-000000000003',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000003')->>'revision')::int,'PUBLISHED')$$,'23514',null,'publication without criteria row denied');
reset role;
insert into public.drive_eligibility(drive_id) values ('74000000-0000-0000-0000-000000000003');
update public.placement_drives set created_at=now()-interval '2 days',application_deadline=now()-interval '1 day' where id='74000000-0000-0000-0000-000000000003';
set local role authenticated;
select throws_ok($$select public.transition_drive('74000000-0000-0000-0000-000000000003',
 (public.staff_drive_detail('74000000-0000-0000-0000-000000000003')->>'revision')::int,'PUBLISHED')$$,'23514',null,'expired draft publication denied');
reset role;
update public.profiles set is_active=false where id='71000000-0000-0000-0000-000000000005';
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
select throws_ok($$select public.student_drive_list()$$,'42501',null,'inactive student cannot read drives');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.transition_drive('74000000-0000-0000-0000-000000000001',1,'CLOSED')$$,'42501',null,'coordinator cannot close');
select throws_ok($$select public.transition_drive('74000000-0000-0000-0000-000000000001',1,'ARCHIVED')$$,'42501',null,'coordinator cannot archive');
reset role;

insert into public.companies(id,name,created_by,updated_by)
values ('78000000-0000-0000-0000-000000000001','Expired-only company','71000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002');
insert into public.placement_drives(id,company_id,title,drive_type,description,created_at,application_deadline)
values ('78000000-0000-0000-0000-000000000002','78000000-0000-0000-0000-000000000001','Only expired drive','PLACEMENT','Expired fixture',now()-interval '2 days',now()-interval '1 day');
insert into public.drive_eligibility(drive_id) values ('78000000-0000-0000-0000-000000000002');
insert into public.drive_eligible_batches(drive_id,course,batch_year) values ('78000000-0000-0000-0000-000000000002','B.Arch',2027);
alter table public.placement_drives disable trigger drives_content_integrity;
update public.placement_drives set status='PUBLISHED',published_at=created_at where id='78000000-0000-0000-0000-000000000002';
alter table public.placement_drives enable trigger drives_content_integrity;
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.set_company_archive_state('78000000-0000-0000-0000-000000000001',true)$$,'23514',null,'expired-only published drive blocks company archive');
select public.transition_drive('78000000-0000-0000-0000-000000000002',
 (public.staff_drive_detail('78000000-0000-0000-0000-000000000002')->>'revision')::int,'CLOSED');
select lives_ok($$select public.set_company_archive_state('78000000-0000-0000-0000-000000000001',true)$$,'explicit closure enables company archival');
select is(jsonb_array_length(public.staff_drive_list(1,'PUBLISHED')),21,'staff list bounded twenty plus lookahead');
select ok(not exists(select 1 from jsonb_array_elements(public.staff_drive_list(1,'PUBLISHED')) with ordinality a(v,n)
 join jsonb_array_elements(public.staff_drive_list(2,'PUBLISHED')) b(v) on a.v->>'id'=b.v->>'id' where a.n<=20),'staff adjacent visible pages distinct');
reset role;

select * from finish();
rollback;
