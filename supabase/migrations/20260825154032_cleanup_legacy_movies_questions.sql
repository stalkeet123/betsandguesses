begin;

with ids(id) as (values
('c8ebe61b-375d-4e71-b587-23ea65de4a36'::uuid),
('7efa6778-64f8-4c9a-9043-c4f4a972806f'),
('da699aae-1dab-408e-a820-2d59a9b3f440'),
('d3788ce8-c69a-496f-9e04-5f0575b6e4ba'),
('c1f09196-87dc-4df9-9c98-d77f26b7b3be'),
('10474696-a6e2-4cf9-b726-27578bbbcc73'),
('5ae19fb9-5e8c-40b7-9e7e-8c53dc26d400'),
('319add7f-7179-443a-9628-a903324cc36c'),
('d7367cff-4110-4fe8-8d09-8f0f347f9e03'),
('a11beccc-b8f6-49ed-b2ea-ac40b2567d1f'),
('1ae0f137-2278-4f58-90ee-c9fcfb3438cf'),
('795b8ae8-23d3-4456-aa98-96b937975b14'),
('bad5dc61-459a-4481-bcc6-6adca6a19247'),
('1671024a-affb-4cba-abbd-4d85d7b3fbb5'),
('9e40de2e-6914-4f6d-a8f7-b8faa6fcbd5b'),
('0829d3da-1051-4077-99f0-1d7732f4a480'),
('59406fcc-f87a-4d57-9e41-36dd4667ce2c'))
update public.rooms r set current_question_id=null from ids where r.current_question_id=ids.id;

with ids(id) as (values
('c8ebe61b-375d-4e71-b587-23ea65de4a36'::uuid),('7efa6778-64f8-4c9a-9043-c4f4a972806f'),('da699aae-1dab-408e-a820-2d59a9b3f440'),('d3788ce8-c69a-496f-9e04-5f0575b6e4ba'),('c1f09196-87dc-4df9-9c98-d77f26b7b3be'),('10474696-a6e2-4cf9-b726-27578bbbcc73'),('5ae19fb9-5e8c-40b7-9e7e-8c53dc26d400'),('319add7f-7179-443a-9628-a903324cc36c'),('d7367cff-4110-4fe8-8d09-8f0f347f9e03'),('a11beccc-b8f6-49ed-b2ea-ac40b2567d1f'),('1ae0f137-2278-4f58-90ee-c9fcfb3438cf'),('795b8ae8-23d3-4456-aa98-96b937975b14'),('bad5dc61-459a-4481-bcc6-6adca6a19247'),('1671024a-affb-4cba-abbd-4d85d7b3fbb5'),('9e40de2e-6914-4f6d-a8f7-b8faa6fcbd5b'),('0829d3da-1051-4077-99f0-1d7732f4a480'),('59406fcc-f87a-4d57-9e41-36dd4667ce2c'))
delete from public.classic_question_history h using ids where h.question_id=ids.id;

with ids(id) as (values
('c8ebe61b-375d-4e71-b587-23ea65de4a36'::uuid),('7efa6778-64f8-4c9a-9043-c4f4a972806f'),('da699aae-1dab-408e-a820-2d59a9b3f440'),('d3788ce8-c69a-496f-9e04-5f0575b6e4ba'),('c1f09196-87dc-4df9-9c98-d77f26b7b3be'),('10474696-a6e2-4cf9-b726-27578bbbcc73'),('5ae19fb9-5e8c-40b7-9e7e-8c53dc26d400'),('319add7f-7179-443a-9628-a903324cc36c'),('d7367cff-4110-4fe8-8d09-8f0f347f9e03'),('a11beccc-b8f6-49ed-b2ea-ac40b2567d1f'),('1ae0f137-2278-4f58-90ee-c9fcfb3438cf'),('795b8ae8-23d3-4456-aa98-96b937975b14'),('bad5dc61-459a-4481-bcc6-6adca6a19247'),('1671024a-affb-4cba-abbd-4d85d7b3fbb5'),('9e40de2e-6914-4f6d-a8f7-b8faa6fcbd5b'),('0829d3da-1051-4077-99f0-1d7732f4a480'),('59406fcc-f87a-4d57-9e41-36dd4667ce2c'))
delete from public.classic_question_serves s using ids where s.question_id=ids.id;

with ids(id) as (values
('c8ebe61b-375d-4e71-b587-23ea65de4a36'::uuid),('7efa6778-64f8-4c9a-9043-c4f4a972806f'),('da699aae-1dab-408e-a820-2d59a9b3f440'),('d3788ce8-c69a-496f-9e04-5f0575b6e4ba'),('c1f09196-87dc-4df9-9c98-d77f26b7b3be'),('10474696-a6e2-4cf9-b726-27578bbbcc73'),('5ae19fb9-5e8c-40b7-9e7e-8c53dc26d400'),('319add7f-7179-443a-9628-a903324cc36c'),('d7367cff-4110-4fe8-8d09-8f0f347f9e03'),('a11beccc-b8f6-49ed-b2ea-ac40b2567d1f'),('1ae0f137-2278-4f58-90ee-c9fcfb3438cf'),('795b8ae8-23d3-4456-aa98-96b937975b14'),('bad5dc61-459a-4481-bcc6-6adca6a19247'),('1671024a-affb-4cba-abbd-4d85d7b3fbb5'),('9e40de2e-6914-4f6d-a8f7-b8faa6fcbd5b'),('0829d3da-1051-4077-99f0-1d7732f4a480'),('59406fcc-f87a-4d57-9e41-36dd4667ce2c'))
delete from public.guesses g using ids where g.question_id=ids.id;

with ids(id) as (values
('c8ebe61b-375d-4e71-b587-23ea65de4a36'::uuid),('7efa6778-64f8-4c9a-9043-c4f4a972806f'),('da699aae-1dab-408e-a820-2d59a9b3f440'),('d3788ce8-c69a-496f-9e04-5f0575b6e4ba'),('c1f09196-87dc-4df9-9c98-d77f26b7b3be'),('10474696-a6e2-4cf9-b726-27578bbbcc73'),('5ae19fb9-5e8c-40b7-9e7e-8c53dc26d400'),('319add7f-7179-443a-9628-a903324cc36c'),('d7367cff-4110-4fe8-8d09-8f0f347f9e03'),('a11beccc-b8f6-49ed-b2ea-ac40b2567d1f'),('1ae0f137-2278-4f58-90ee-c9fcfb3438cf'),('795b8ae8-23d3-4456-aa98-96b937975b14'),('bad5dc61-459a-4481-bcc6-6adca6a19247'),('1671024a-affb-4cba-abbd-4d85d7b3fbb5'),('9e40de2e-6914-4f6d-a8f7-b8faa6fcbd5b'),('0829d3da-1051-4077-99f0-1d7732f4a480'),('59406fcc-f87a-4d57-9e41-36dd4667ce2c'))
delete from public.questions q using ids where q.id=ids.id;

do $$
begin
  if exists (select 1 from public.questions where id in (
    'c8ebe61b-375d-4e71-b587-23ea65de4a36'::uuid,'7efa6778-64f8-4c9a-9043-c4f4a972806f','da699aae-1dab-408e-a820-2d59a9b3f440','d3788ce8-c69a-496f-9e04-5f0575b6e4ba','c1f09196-87dc-4df9-9c98-d77f26b7b3be','10474696-a6e2-4cf9-b726-27578bbbcc73','5ae19fb9-5e8c-40b7-9e7e-8c53dc26d400','319add7f-7179-443a-9628-a903324cc36c','d7367cff-4110-4fe8-8d09-8f0f347f9e03','a11beccc-b8f6-49ed-b2ea-ac40b2567d1f','1ae0f137-2278-4f58-90ee-c9fcfb3438cf','795b8ae8-23d3-4456-aa98-96b937975b14','bad5dc61-459a-4481-bcc6-6adca6a19247','1671024a-affb-4cba-abbd-4d85d7b3fbb5','9e40de2e-6914-4f6d-a8f7-b8faa6fcbd5b','0829d3da-1051-4077-99f0-1d7732f4a480','59406fcc-f87a-4d57-9e41-36dd4667ce2c')) then
    raise exception 'Legacy Movies cleanup verification failed';
  end if;
end $$;

commit;