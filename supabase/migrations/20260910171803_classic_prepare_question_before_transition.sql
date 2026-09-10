-- Prepare the next Classic question under the room lock BEFORE publishing
-- the transition. Existing clients keep using claim_game_phase_v1 safely.
CREATE OR REPLACE FUNCTION public.claim_game_phase_v1(
  p_room_id uuid,
  p_round_number integer,
  p_expected_phase text,
  p_next_phase text,
  p_duration_seconds integer DEFAULT NULL,
  p_next_round integer DEFAULT NULL,
  p_current_question_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
  v_started_at timestamptz;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if p_duration_seconds is not null and p_duration_seconds not between 1 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;
  if p_round_number is null or p_round_number < 1
     or p_expected_phase is null or p_next_phase is null then
    raise exception using errcode = '22023', message = 'Invalid phase claim';
  end if;
  if not (
    (p_expected_phase = 'guessing' and p_next_phase = 'betting') or
    (p_expected_phase = 'revealAnswer' and p_next_phase = 'question')
  ) then
    raise exception using errcode = '22023', message = 'Invalid phase transition';
  end if;
  if p_current_question_id is not null then
    raise exception using errcode = '22023', message = 'Client question selection is disabled';
  end if;
  if (p_expected_phase = 'revealAnswer' and
      (p_next_round is null or p_next_round <> p_round_number + 1))
     or (p_expected_phase = 'guessing' and
         p_next_round is not null and p_next_round <> p_round_number) then
    raise exception using errcode = '22023', message = 'Invalid next round';
  end if;

  -- Validate AFTER acquiring the lock: another member may have won the claim.
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.game_mode <> 'classic'
     or v_room.status <> 'playing'
     or v_room.current_round <> p_round_number
     or v_room.round_phase <> p_expected_phase
     or (v_room.phase_ends_at is not null and
         v_room.phase_ends_at > clock_timestamp()) then
    return null;
  end if;

  v_question_id := v_room.current_question_id;
  if p_next_phase = 'question' then
    if p_next_round > v_room.max_rounds then return null; end if;
    -- Retain the existing tier, category and no-repeat selection policy.
    -- Picker writes and this phase update commit in the same transaction.
    v_question_id := public.pick_question_id_v3(p_room_id, v_room.category);
    if v_question_id is null then
      raise exception using errcode = 'P0002', message = 'No question available';
    end if;
  end if;
  -- Lock waits / question selection must not consume the transition window.
  v_started_at := clock_timestamp();
  update public.rooms
  set current_round = coalesce(p_next_round, p_round_number),
      round_phase = p_next_phase,
      current_question_id = v_question_id,
      phase_started_at = v_started_at,
      phase_ends_at = case when p_duration_seconds is null then null
        else v_started_at + make_interval(secs => p_duration_seconds) end
  where id = p_room_id
  returning * into v_room;
  return to_jsonb(v_room);
end;
$function$;

-- Fast path for updated clients: ship question text with the transition,
-- without a second network request. The called RPCs enforce membership.
CREATE OR REPLACE FUNCTION public.prepare_next_classic_round_v1(
  p_room_id uuid,
  p_round_number integer,
  p_transition_seconds integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
declare
  v_room jsonb;
begin
  if p_transition_seconds is null or p_transition_seconds not between 1 and 300 then
    raise exception using errcode = '22023', message = 'Invalid transition duration';
  end if;
  v_room := public.claim_game_phase_v1(
    p_room_id, p_round_number, 'revealAnswer', 'question',
    p_transition_seconds, p_round_number + 1, null
  );
  if v_room is null then return null; end if;
  return jsonb_build_object(
    'room', v_room,
    'question', public.get_current_question_v2(p_room_id)
  );
end;
$function$;

REVOKE ALL ON FUNCTION public.prepare_next_classic_round_v1(uuid, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.prepare_next_classic_round_v1(uuid, integer, integer) TO authenticated, service_role;

-- Apply the same post-preparation clock boundary to the first round and guessing.
CREATE OR REPLACE FUNCTION public.start_game_v4(p_room_id uuid, p_duration_seconds integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
  v_scores jsonb;
  v_started_at timestamptz;
begin
  if (select auth.uid()) is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  if p_duration_seconds not between 5 and 300 then raise exception using errcode='22023',message='Invalid duration'; end if;
  select * into v_room from public.rooms where id=p_room_id for update;
  if not found then raise exception using errcode='P0002',message='Room not found'; end if;
  if coalesce(v_room.game_mode,'classic')<>'classic' then raise exception using errcode='P0002',message='Classic room not found'; end if;
  if not exists(select 1 from public.players p where p.room_id=p_room_id and p.auth_user_id=(select auth.uid()) and p.is_host=true and p.is_connected=true) then raise exception using errcode='42501',message='Host access required'; end if;
  if v_room.status='playing' and v_room.current_question_id is not null then
    select coalesce(jsonb_object_agg(p.id::text,p.score),'{}'::jsonb) into v_scores from public.players p where p.room_id=p_room_id and p.is_connected;
    return jsonb_build_object('room',to_jsonb(v_room),'question',public.public_question_json_v2(v_room.current_question_id,false),'scores',v_scores);
  end if;
  if v_room.status<>'waiting' then raise exception using errcode='40001',message='Room is not waiting'; end if;
  if (select count(*) from public.players p where p.room_id=p_room_id and p.is_connected)<2 then raise exception using errcode='P0001',message='At least two players required'; end if;
  if exists(select 1 from public.players p where p.room_id=p_room_id and p.is_connected and not p.is_host and not p.is_ready) then raise exception using errcode='P0001',message='All players must be ready'; end if;
  perform public.consume_host_game_credit_v1();
  update public.rooms set classic_match_id=gen_random_uuid() where id=p_room_id returning * into v_room;
  v_question_id:=public.pick_question_id_v3(p_room_id,v_room.category);
  if v_question_id is null then raise exception using errcode='P0002',message='No question available'; end if;
  update public.players set score=15 where room_id=p_room_id and is_connected;
  v_started_at := clock_timestamp();
  update public.rooms set status='playing',current_round=1,round_phase='question',current_question_id=v_question_id,phase_started_at=v_started_at,phase_ends_at=v_started_at+interval '1 second' where id=p_room_id returning * into v_room;
  select coalesce(jsonb_object_agg(p.id::text,p.score),'{}'::jsonb) into v_scores from public.players p where p.room_id=p_room_id and p.is_connected;
  return jsonb_build_object('room',to_jsonb(v_room),'question',public.public_question_json_v2(v_question_id,false),'scores',v_scores);
end; $function$;

CREATE OR REPLACE FUNCTION public.claim_next_question_v3(p_room_id uuid, p_round_number integer, p_duration_seconds integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_room public.rooms%rowtype; v_question_id uuid; v_host_user_id uuid; v_normalized_text text; v_started_at timestamptz;
begin
 if not public.is_room_member_v2(p_room_id) then raise exception using errcode='42501',message='Room membership required'; end if;
 if p_duration_seconds not between 5 and 300 then raise exception using errcode='22023',message='Invalid duration'; end if;
 select * into v_room from public.rooms where id=p_room_id for update;
 if not found or coalesce(v_room.game_mode,'classic')<>'classic' or v_room.status<>'playing' or v_room.current_round<>p_round_number or v_room.round_phase<>'question' then return null; end if;
 if v_room.phase_ends_at is not null and v_room.phase_ends_at>clock_timestamp() then return null; end if;
 if v_room.classic_match_id is null then update public.rooms set classic_match_id=gen_random_uuid() where id=p_room_id returning * into v_room; end if;
 if v_room.current_question_id is not null then
  v_host_user_id:=v_room.created_by;
  if v_host_user_id is null then select p.auth_user_id into v_host_user_id from public.players p where p.room_id=p_room_id and coalesce(p.is_host,false)=true and p.auth_user_id is not null order by p.joined_at nulls last,p.id limit 1; end if;
  if v_host_user_id is not null then
   insert into public.monetization_profiles(user_id) values(v_host_user_id) on conflict(user_id) do nothing;
   perform 1 from public.monetization_profiles where user_id=v_host_user_id for update;
   select lower(btrim(q.text_en)) into v_normalized_text from public.questions q where q.id=v_room.current_question_id;
   if v_normalized_text is not null then insert into public.classic_question_serves(room_id,match_id,host_user_id,question_id,normalized_text) values(p_room_id,v_room.classic_match_id,v_host_user_id,v_room.current_question_id,v_normalized_text) on conflict do nothing; end if;
  end if;
  v_question_id:=v_room.current_question_id;
 else
  v_question_id:=public.pick_question_id_v3(p_room_id,v_room.category);
 end if;
 if v_question_id is null then raise exception using errcode='P0002',message='No question available'; end if;
 v_started_at := clock_timestamp();
 update public.rooms set round_phase='guessing',current_question_id=v_question_id,phase_started_at=v_started_at,phase_ends_at=v_started_at+make_interval(secs=>p_duration_seconds) where id=p_room_id returning * into v_room;
 return jsonb_build_object('room',to_jsonb(v_room),'question',public.public_question_json_v2(v_question_id,false));
end; $function$;
