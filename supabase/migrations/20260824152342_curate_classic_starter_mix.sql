begin;

do $$
declare
  v_starter_ids constant uuid[] := array[
    '0cc99c80-c004-4baa-8746-62431b26b794'::uuid,
    '128c424f-0472-42f0-ab4b-989f7636fc13'::uuid,
    '2716f6a3-7146-4f8f-a10a-3af0a7fd80e1'::uuid,
    '24077017-84e0-4938-a9f7-5c212e496bc0'::uuid,
    '05306a51-e0df-48f8-9215-80304a30aeee'::uuid,
    '668a1adf-71f5-42f8-be3a-ea4dbcab7b8e'::uuid,
    '6fe1fe11-1441-4005-a627-c2c99ff8acee'::uuid,
    '5d017ca8-73d2-4c60-abe2-ec83c1ab597f'::uuid,
    '4f5867d0-7c40-4f3a-b5ed-8d60ccc47301'::uuid,
    '1d3f9941-72c3-43e4-be8f-b95ce640654e'::uuid,
    'dd1f5ef2-4412-4e0d-81ab-54cfcfd740b8'::uuid,
    '4903e96d-f040-4ea3-9767-834714ecc39c'::uuid,
    '4cdac363-4363-4ba8-946e-2f4fddff99df'::uuid,
    '22a9ae9d-348f-4023-871b-33dc73d03ca3'::uuid,
    '70a7772d-574c-4e6b-8d2a-adc74793b620'::uuid,
    '352d27e6-c73a-4fe8-89be-cf14f1a905cd'::uuid,
    '0382cd61-6430-4ca5-a815-933d024b4bb0'::uuid,
    '7d4e02e8-16da-4be1-a1b4-061c77889e89'::uuid,
    'a3f75a76-a944-4cb1-a0cd-52f316764c51'::uuid,
    'e4a2d0c0-8f7f-4d1f-89a3-19b4b7a8eaf1'::uuid,
    '2ad357e2-5581-4228-ab2e-c9f8ca37201f'::uuid,
    'c4f89241-418f-4d77-b149-ef079da64d16'::uuid,
    '369e981a-e2a4-4126-9e6c-a1ca8dd4317d'::uuid,
    '8f83a79d-3e08-44af-a80f-1ab0bff3ca5a'::uuid,
    'c7d92074-7523-4e35-9907-7519c2718cda'::uuid,
    'e890de4a-441e-493c-80d4-2cc076dca38f'::uuid,
    '1682e833-092d-47d1-a5ea-c99ebf500623'::uuid,
    'dcc0ab11-09c0-469b-b661-15a13868286e'::uuid,
    '5b695049-d4d8-4fe5-b919-b3ce09f24937'::uuid,
    '277bc785-e138-44a2-a5fa-9068e848890d'::uuid,
    '511ca321-4c2e-4693-92f5-be21da91f5c8'::uuid,
    '284d86ab-e479-449d-b36b-243e983cf01f'::uuid,
    '0b2501fe-bcb3-414e-b4ed-051046d38ae1'::uuid,
    '0dbcb256-6e16-4176-bdc6-49c7f2cf7299'::uuid,
    '40153bd7-e60d-4e58-9597-05aa7bc61c21'::uuid,
    '0a97ce64-dc02-4cfb-9608-b8ec8cf8c32a'::uuid,
    '525e237b-ccf4-4cde-aa9c-bd74c1f2252c'::uuid,
    '12e50410-c2e9-4dce-a18a-2ae174e87f2b'::uuid,
    'ef6a8450-118c-4385-9c95-1dacd28ad7ed'::uuid,
    '9bf1bc4d-a1d4-4578-b65f-9cdec70ee765'::uuid,
    '07b0a041-d2b8-425a-9b39-24c5f9fbcbee'::uuid,
    '1e872fe4-3bf0-45e9-9eeb-7754596c2688'::uuid,
    '0c2c35b4-3532-40b3-b0c4-c15e7db0e2da'::uuid,
    '1569255b-2bcb-4f48-b058-33284246a9cd'::uuid,
    '09275a5e-5059-44e4-af93-d11ecc8c66e5'::uuid,
    '35dbc99e-3599-414e-a667-e29d530ea222'::uuid,
    '2629bd97-6a80-4491-88f4-3f27189bf45e'::uuid,
    '0232f4b9-6293-46b2-99b6-4535538be79e'::uuid,
    '2d4d9c09-f7da-4288-8aef-69814b4a08a0'::uuid,
    '590cb5cb-802a-4b84-8cbf-9b9409af2170'::uuid,
    '8ca6ca48-ae6b-4192-beb8-5561d911dbd6'::uuid,
    '94f23526-6cbf-44b8-be3c-776562bb77a7'::uuid,
    '14b0eabf-9130-467b-ad4e-3383fc418049'::uuid,
    '5bd34739-8d45-4372-b78b-2b4a1931048f'::uuid,
    'a49dc41e-a14c-4362-b11a-8dd7a79a7d30'::uuid,
    '10474696-a6e2-4cf9-b726-27578bbbcc73'::uuid,
    '5ae19fb9-5e8c-40b7-9e7e-8c53dc26d400'::uuid,
    '1ae0f137-2278-4f58-90ee-c9fcfb3438cf'::uuid,
    '1671024a-affb-4cba-abbd-4d85d7b3fbb5'::uuid,
    '0829d3da-1051-4077-99f0-1d7732f4a480'::uuid,
    '7efa6778-64f8-4c9a-9043-c4f4a972806f'::uuid,
    'eaf485e0-e553-4b1e-9b00-0e018896526e'::uuid,
    'c24e1484-78c8-4b47-8204-f5668a0ede7a'::uuid,
    '6c1a57f2-f35c-4e5c-8c25-665439df2c82'::uuid,
    '1dddbacd-b644-48c9-ae37-1b088cbaed7a'::uuid,
    '7893a9d5-0b04-44bc-912c-eae0a8c887c4'::uuid,
    '6b0565f3-725d-413c-a1cd-b9016a02e580'::uuid,
    '4f5ffc53-4712-4617-affb-a2d95fceee1f'::uuid,
    '2d456cbc-85b2-40e1-a680-48799b7eefd7'::uuid,
    'b78bc67e-d240-4ae7-b6ca-9a0214e671f9'::uuid,
    '63106867-228b-4632-8670-b3a7c0424f61'::uuid,
    '1f0bd181-4481-476b-ac2b-8e6854447c60'::uuid,
    '5c40d600-7024-44ce-9d0c-956bb5a33c20'::uuid,
    '68f45514-388e-4480-9f01-8a2e03e736e9'::uuid,
    'd9d6494e-24ce-4e24-a2fc-557be5a1bec4'::uuid,
    '44973b68-19b9-4644-a370-2fd5612c1560'::uuid,
    '00d8e94a-46e5-49c5-bf21-8244423a7332'::uuid,
    '6473605c-5b81-4436-9ff4-560954320607'::uuid,
    'e10cdf7a-b688-43d0-95be-0227004a2504'::uuid,
    'eb61b9ee-4c98-4d69-ac79-ec590c255dff'::uuid,
    'e68b852f-77b3-40ed-a1a0-8feffdca2f1f'::uuid,
    '33cd957e-a0eb-402c-a46d-6c641a8ab064'::uuid,
    '0337b755-2714-41eb-94bd-b4fe80434bb1'::uuid,
    '8408d39e-3b3d-478e-91b3-3be899910b44'::uuid,
    'bec5f9ad-3934-464d-850a-4a7cb20fa413'::uuid,
    '909ff6a6-6438-407f-ad78-1bcf32b388af'::uuid,
    '0da15469-f62a-4af0-8a85-72f26877a599'::uuid,
    '50c5e004-3cbe-43ea-bba7-6507dc8c9a0c'::uuid,
    '547199bd-d476-425e-984a-6caaf3de5530'::uuid,
    '8b0002dc-cc1d-46df-acc9-f24e983a2f3a'::uuid,
    '0125f085-a8f2-4b85-b732-e4ba81fa94ef'::uuid,
    '9bcd9c76-74cd-4274-8ac1-a149739d5ef6'::uuid,
    '18128be3-c210-4798-a8a0-ed6c74982c15'::uuid,
    '374e79e2-0d8f-4c38-aeb6-2ec28c293042'::uuid,
    '5d66c307-5914-4de3-b19a-c87ae6bc516d'::uuid,
    '65331993-84af-48ca-9848-25d6e5508615'::uuid,
    '0697eb4f-23d2-4070-a6ee-4761e8e5fded'::uuid,
    '3bcf9a34-d212-4007-978d-5d173afa1252'::uuid,
    '402c9884-dff3-40a1-b806-f4b77f6bf03e'::uuid,
    '8ec942e3-d246-4132-8a9f-fd9e76cc256c'::uuid
  ];
  v_expected_category_counts constant jsonb :=
    '{"animals": 10, "food": 10, "general": 10, "geography": 15, "history": 10, "movies": 6, "music": 5, "science": 12, "sports": 12, "technology": 10}'::jsonb;
  v_starter_count integer;
  v_distinct_normalized_text_count integer;
  v_existing_id_count integer;
  v_unlisted_nonpremium_count integer;
  v_category_counts jsonb;
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'questions'
      and column_name = 'access_tier'
  ) then
    raise exception 'questions.access_tier must exist before curating the Starter Mix';
  end if;

  if cardinality(v_starter_ids) <> 100 then
    raise exception 'Starter Mix must contain exactly 100 IDs; found %', cardinality(v_starter_ids);
  end if;

  if (
    select count(distinct selected_id)
    from unnest(v_starter_ids) as selected(selected_id)
  ) <> 100 then
    raise exception 'Starter Mix ID list contains duplicate IDs';
  end if;

  select count(*) into v_existing_id_count
  from public.questions
  where id = any(v_starter_ids);

  if v_existing_id_count <> 100 then
    raise exception 'Starter Mix requires 100 existing questions; found %', v_existing_id_count;
  end if;

  -- public.questions is the Classic bank. Party prompts live in party_challenges.
  update public.questions
  set access_tier = 'premium';

  update public.questions
  set access_tier = 'starter'
  where id = any(v_starter_ids);

  select count(*) into v_starter_count
  from public.questions
  where access_tier = 'starter';

  if v_starter_count <> 100 then
    raise exception 'Starter Mix must contain exactly 100 rows; found %', v_starter_count;
  end if;

  select count(distinct lower(btrim(text_en)))
    into v_distinct_normalized_text_count
  from public.questions
  where access_tier = 'starter';

  if v_distinct_normalized_text_count <> 100 then
    raise exception
      'Starter Mix must contain 100 distinct normalized English texts; found %',
      v_distinct_normalized_text_count;
  end if;

  if exists (
    select 1
    from public.questions
    where access_tier = 'starter'
      and coalesce(lower(btrim(category)), '<null>') not in (
        'animals', 'food', 'general', 'geography', 'history',
        'movies', 'music', 'science', 'sports', 'technology'
      )
  ) then
    raise exception 'Starter Mix contains an unexpected category';
  end if;

  select coalesce(jsonb_object_agg(category_key, row_count), '{}'::jsonb)
    into v_category_counts
  from (
    select
      coalesce(lower(btrim(category)), '<null>') as category_key,
      count(*) as row_count
    from public.questions
    where access_tier = 'starter'
    group by coalesce(lower(btrim(category)), '<null>')
  ) as starter_categories;

  if v_category_counts <> v_expected_category_counts then
    raise exception
      'Starter Mix category counts mismatch. Expected %, got %',
      v_expected_category_counts,
      v_category_counts;
  end if;

  select count(*) into v_unlisted_nonpremium_count
  from public.questions
  where id <> all(v_starter_ids)
    and access_tier <> 'premium';

  if v_unlisted_nonpremium_count <> 0 then
    raise exception 'All unlisted questions must remain premium; found % exceptions', v_unlisted_nonpremium_count;
  end if;
end;
$$;

commit;