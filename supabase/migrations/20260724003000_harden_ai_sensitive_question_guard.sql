create or replace function private.ai_question_contains_blocked_topic(
  requested_question text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(requested_question, '') ~* (
    '(성관계|성생활|섹스|임신|출산|난임'
    || '|경제[[:space:]]*(상황|문제|고민|사정)'
    || '|재정|소득|연봉|월급|재산|저축|금전|지출|생활비'
    || '|대출|부채|빚|돈[[:space:]]*(문제|고민|관리)'
    || '|투자[[:space:]]*(금|성향|계획|손실|수익)'
    || '|건강[[:space:]]*(상태|문제|고민|검진)'
    || '|몸[[:space:]]*(상태|건강)|질병|질환|병원'
    || '|치료|수술|복약|통증|아프'
    || '|정신[[:space:]]*건강|정신[[:space:]]*질환'
    || '|트라우마|종교|정치'
    || '|(가족|부모|시댁|처가).{0,30}(갈등|다툼|불화|싸움)'
    || '|sexual|pregnan|fertility|debt|financial'
    || '|salary|income|money|loan|investment'
    || '|physical[[:space:]]*health|medical|illness|disease'
    || '|surgery|medication|mental[[:space:]]*health|trauma'
    || '|religion|politic|family.{0,30}(conflict|fight))'
  );
$$;
