import assert from 'node:assert/strict';
import { test } from 'node:test';
import { CuratedProactiveSuggestionSelector } from '../src/application/curated-proactive-suggestion-selector.ts';

test('visible monthly coffee wish influences reviewed recommendation selection', () => {
  const selector = new CuratedProactiveSuggestionSelector();
  for (let day = 1; day <= 10; day++) {
    const result = selector.select({
      userId:'a',localDate:`2026-10-${String(day).padStart(2,'0')}`,localHour:12,
      hasCardToday:true,recordingAvailable:false,weather:null,
      reflectionAnswerTexts:['다음 달에는 같이 커피 한 잔 마시고 싶어'],
    });
    assert.equal(result.id,'together_06');
    assert.equal(result.text.includes('다음 달에는'),false);
  }
});

test('negative reflection wording does not select an unwanted activity', () => {
  const selector = new CuratedProactiveSuggestionSelector();
  const base = {userId:'a',localDate:'2026-10-02',localHour:12,hasCardToday:true,recordingAvailable:false,weather:null};
  assert.deepEqual(selector.select({...base,reflectionAnswerTexts:['커피는 싫어. 마시고 싶지 않아']}),selector.select(base));
});
