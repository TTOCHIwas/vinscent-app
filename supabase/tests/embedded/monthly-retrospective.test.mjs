import assert from 'node:assert/strict';
import { before, after, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const a='00000000-0000-0000-0000-000000000001';
const b='00000000-0000-0000-0000-000000000002';
const c='00000000-0000-0000-0000-000000000003';
let month;
const sql = async (text, params=[]) => (await db.query(text,params)).rows;
const data = async () => (await sql('select public.get_current_monthly_retrospective() as data'))[0].data;
const login = (id) => sql("select set_config('test.user',$1,false)",[id]);

before(async () => {
  await db.exec(await readFile(new URL('monthly-fixture.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../../migrations/20261011112004_add_monthly_retrospective.sql',import.meta.url),'utf8'));
  await sql('insert into auth.users values($1),($2)',[a,b]);
  await sql("insert into public.couples values($1,$2,$3,'UTC','active')",[c,a,b]);
  month = (await sql("select to_char(date_trunc('month',now())-interval '1 month','YYYY-MM-DD') as month"))[0].month;
  await login(a);
});
after(() => db.close());

async function card(day,user=a,photo=true,featured=true) {
  return (await sql(`insert into public.story_loop_cards(couple_id,couple_date,author_user_id,artifact_revision,preview_path,scene_data_path,has_photo,is_featured)
    values($1,$2::date+($3::integer-1),$4,gen_random_uuid(),'preview','scene',$5,$6) returning id`,[c,month,day,user,photo,featured]))[0].id;
}
async function question(day,answers) {
  const id=(await sql("insert into public.questions values(gen_random_uuid(),'원래 질문') returning id"))[0].id;
  const daily=(await sql('insert into public.daily_questions values(gen_random_uuid(),$1,$2::date+($3::integer-1),$4) returning id',[c,month,day,id]))[0].id;
  for(let i=0;i<answers.length;i++) await sql('insert into public.daily_question_answers(daily_question_id,user_id,answer_text) values($1,$2,$3)',[daily,i===0?a:b,answers[i]]);
  return daily;
}

test('empty month has no input, and incomplete counts are not zero', async () => {
  const result=await data();
  assert.equal(result.has_records,false);
  assert.equal(result.card_count,null);
  assert.equal(result.reflection,null);
});

test('selects photo dates by answer presence, stripped length and early ties',async () => {
  await card(2);await card(3);await card(11);await card(12);await card(25);await card(26);
  await question(2,[]);await question(3,['가']);
  await question(11,['가 나\n다','라']);await question(12,['가나다라']);
  await question(25,['다섯글자답']);await question(26,['짧은말']);
  const result=await data();
  assert.deepEqual(result.moments.map(m=>Number(m.date.slice(-2))),[3,11,25]);
  assert.equal(result.recorded_days,6);
  assert.equal(result.completed_questions,1);
  assert.equal(result.conversation.my_answer,'가 나\n다');
  assert.equal(result.moments[0].question,'원래 질문');
  assert.equal('first_answer' in result.moments[0],false);
  await login(b);
  assert.deepEqual((await data()).moments,result.moments);
  await login(a);
});

test('retains each author featured card rather than exposing rollover siblings',async()=>{
  await card(3,b);
  await card(3,a,true,false);
  const result=await data();
  assert.equal(result.moments[0].cards.length,2);
  assert.equal(result.moments[0].cards[0].aspect_ratio,0.8);
});

test('fixed question survives generation and partner stays hidden until own answer',async()=>{
  const first=await data();const id=first.reflection.id;
  await login(b);
  await sql('select public.submit_current_monthly_retrospective_answer($1,$2,0)',[id,'같이 산책하기']);
  await login(a);
  assert.equal((await data()).reflection.partner_answer,null);
  await assert.rejects(sql('select public.submit_current_monthly_retrospective_answer($1,$2,0)',[id,' '.repeat(4)]));
  await assert.rejects(sql('select public.submit_current_monthly_retrospective_answer($1,$2,0)',[id,'가'.repeat(501)]));
  const saved=(await sql('select public.submit_current_monthly_retrospective_answer($1,$2,0) as data',[id,' 함께 커피 마시기\n']))[0].data;
  assert.equal(saved.reflection.my_answer,' 함께 커피 마시기\n');
  assert.equal(saved.reflection.partner_answer,'같이 산책하기');
  await assert.rejects(sql('select public.submit_current_monthly_retrospective_answer($1,$2,0)',[id,'충돌']));
  await sql('insert into public.ai_user_consents values($1,$2,1,true),($1,$3,1,true)',[c,a,b]);
  const claim=(await sql('select public.prepare_monthly_retrospective_generation($1) as data',[a]))[0].data;
  assert.equal(claim.claimed,true);
  assert.equal((await sql('select public.prepare_monthly_retrospective_generation($1) as data',[b]))[0].data.claimed,false);
  const content={title:'함께 쉰 시간',summary_sentences:['함께 이야기했어.','다시 돌아보자.'],question:'다음에는 뭐 하고 싶어?'};
  await sql('select public.finish_monthly_retrospective_generation($1,$2,$3::jsonb)',[id,claim.token,JSON.stringify(content)]);
  assert.equal((await data()).reflection.question,first.reflection.question);
  assert.equal((await data()).summary,content.summary_sentences.join(' '));
});

test('direct deletion decrements and replay creates only one counted card',async()=>{
  const artifact=(await sql('select gen_random_uuid() as id'))[0].id;
  const write="select * from public.upsert_today_story_loop_card($1,'p','s',null,true,false,false,0,0,null)";
  const first=(await sql(write,[artifact]))[0];
  const second=(await sql(write,[artifact]))[0];
  assert.equal(first.card_id,second.card_id);
  assert.equal((await sql('select card_count from private.story_card_daily_counts where couple_date=current_date'))[0].card_count,1);
  await sql('select public.delete_story_card($1)',[first.card_id]);
  assert.equal((await sql('select card_count from private.story_card_daily_counts where couple_date=current_date'))[0].card_count,0);
  await assert.rejects(sql(write,[artifact]));
});

test('automatic row removal preserves write counts and full-month coverage returns a number',async()=>{
  const id=await card(9,a,true,false);
  const before=(await sql('select sum(card_count)::integer as total from private.story_card_daily_counts where couple_date<$1::date+interval \'1 month\'',[month]))[0].total;
  await sql('delete from public.story_loop_cards where id=$1',[id]);
  await sql("update private.story_card_count_coverage set started_at=$1::date-interval '1 day'",[month]);
  assert.equal((await data()).card_count,before);
});

test('expired answers and disconnected couples cannot be read or written',async()=>{
  const id=(await data()).reflection.id;
  await sql("update public.monthly_retrospectives set available_until=now()-interval '1 second' where id=$1",[id]);
  await assert.rejects(sql('select public.submit_current_monthly_retrospective_answer($1,$2,1)',[id,'늦은 저장']));
  await sql("update public.couples set status='disconnected' where id=$1",[c]);
  await assert.rejects(data());
  await assert.rejects(sql('select public.prepare_monthly_retrospective_generation($1)',[a]));
});
