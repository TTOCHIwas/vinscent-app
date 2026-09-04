import type {
  ProactiveSuggestionCandidate,
  ProactiveSuggestionKind,
  ProactiveWeatherContext,
} from '../domain/learning-contract.ts';

export type CuratedProactiveSuggestionTarget =
  | 'together'
  | 'card'
  | 'recording';

export type CuratedProactiveSuggestionStyle = 'soft' | 'active';

export type CuratedProactiveSuggestionCondition =
  | 'always'
  | 'card_missing'
  | 'recording_available'
  | 'morning'
  | 'daytime'
  | 'night'
  | 'outdoor_ok'
  | 'near_sunset'
  | 'cloudy'
  | 'rain_possible'
  | 'snow_possible'
  | 'hot'
  | 'cold';

export interface CuratedProactiveSuggestion {
  id: string;
  target: CuratedProactiveSuggestionTarget;
  style: CuratedProactiveSuggestionStyle;
  conditions: readonly CuratedProactiveSuggestionCondition[];
  text: string;
  kind: ProactiveSuggestionKind;
}

export interface CuratedProactiveSuggestionSelectionContext {
  userId: string;
  localDate: string;
  localHour: number;
  hasCardToday: boolean;
  recordingAvailable: boolean;
  weather: ProactiveWeatherContext | null;
}

export interface SelectedCuratedProactiveSuggestion
  extends ProactiveSuggestionCandidate {
  id: string;
  target: CuratedProactiveSuggestionTarget;
  style: CuratedProactiveSuggestionStyle;
  conditions: readonly CuratedProactiveSuggestionCondition[];
}

const targetOrder: readonly CuratedProactiveSuggestionTarget[] = [
  'together',
  'card',
  'recording',
];

export const curatedProactiveSuggestionCatalog = [
  suggestion('together_01', 'together', 'active', ['always'],
    '같이 먹고 싶은 간식 하나 골라서 같이 먹자!'),
  suggestion('together_02', 'together', 'soft', ['always'],
    '요즘 자주 듣는 노래 하나 상대방에게 들려주는 건 어때?'),
  suggestion('together_03', 'together', 'soft', ['always'],
    '오늘 있었던 일 하나 먼저 꺼내 얘기해볼까?'),
  suggestion('together_04', 'together', 'soft', ['always'],
    '사진첩에서 예전 사진 하나 골라 같이 다시 볼까?'),
  suggestion('together_05', 'together', 'active', ['always'],
    '둘이 다음에 가보고 싶은 곳을 하나씩 얘기해보자!'),
  suggestion('together_06', 'together', 'soft', ['always'],
    '카페 가서 서로 좋아하는 음료 소개해주는 거 어때?'),
  suggestion('together_07', 'together', 'active', ['always'],
    '오늘 가장 웃겼던 순간 하나 상대방에게 들려줘!'),
  suggestion('together_08', 'together', 'active', ['always'],
    '같이 보고 싶은 영화나 영상 하나 골라서 보내봐!'),
  suggestion('together_09', 'together', 'soft', ['always'],
    '상대방에게 지금 필요한 게 휴식인지 대화인지 물어봐도 좋겠는데?'),
  suggestion('together_10', 'together', 'active', ['always'],
    '상대방 웃게 할 말 하나 해봐!'),
  suggestion('together_11', 'together', 'soft', ['always'],
    '오늘 먹고 싶은 메뉴 하나 말하고 상대방 것도 물어볼까?'),
  suggestion('together_12', 'together', 'active', ['always'],
    '둘만 아는 농담 하나 꺼내봐!'),
  suggestion('together_13', 'together', 'soft', ['always'],
    '상대방의 좋은 점 하나 바로 말해주는 건 어때?'),
  suggestion('together_14', 'together', 'active', ['always'],
    '상대방 말투로 오늘 하루를 한번 정리해봐!'),
  suggestion('together_15', 'together', 'soft', ['always'],
    '다음에 같이 해보고 싶은 걸 하나 골라서 얘기해볼까?'),
  suggestion('together_16', 'together', 'soft', ['always'],
    '서로 지금 먹고 싶은 거 하나씩 알려줘도 재밌겠는데?'),

  suggestion('card_01', 'card', 'active', ['card_missing'],
    '상대방에게 보여주고 싶은 장면이 있으면 카드로 한 장 남겨봐!'),
  suggestion('card_02', 'card', 'soft', ['card_missing'],
    '오늘 마음에 남은 순간 하나를 사진이나 그림으로 남겨볼까?'),
  suggestion('card_03', 'card', 'active', ['card_missing'],
    '지금 눈에 들어오는 색 하나 골라서 짧게 그려봐!'),
  suggestion('card_04', 'card', 'soft', ['card_missing'],
    '지나칠 뻔한 오늘의 한 장면을 카드에 담아볼까?'),
  suggestion('card_05', 'card', 'active', ['card_missing'],
    '오늘 기억하고 싶은 장면 하나 사진으로 남겨봐!'),
  suggestion('card_06', 'card', 'active', ['card_missing'],
    '지금 기분을 닮은 낙서 하나 그려봐!'),
  suggestion('card_07', 'card', 'active', ['card_missing'],
    '상대방이 보면 웃을 것 같은 장면을 카드로 보내봐!'),
  suggestion('card_08', 'card', 'active', ['card_missing'],
    '하루가 끝나기 전에 오늘을 떠올리게 하는 물건 하나 찍어봐!'),
  suggestion('card_09', 'card', 'active', ['card_missing'],
    '상대방에게 보여주고 싶은 사진 하나 찍어 올려봐!'),
  suggestion('card_10', 'card', 'soft', ['card_missing'],
    '특별한 일이 없어도 평범한 오늘을 카드 한 장으로 남겨볼까?'),
  suggestion('card_11', 'card', 'active', ['card_missing'],
    '사진첩에서 웃음 나는 사진 하나 골라 카드로 올려봐!'),
  suggestion('card_12', 'card', 'active', ['card_missing'],
    '상대방이 맞힐 수 있게 오늘을 그림으로 표현해봐!'),
  suggestion('card_13', 'card', 'soft', ['card_missing'],
    '오늘 같이 있다면 상대방 사진 한 장 찍어주는 건 어때?'),
  suggestion('card_14', 'card', 'active', ['card_missing'],
    '둘만 알아볼 수 있는 낙서 하나 카드로 남겨봐!'),

  suggestion('recording_01', 'recording', 'active', ['recording_available'],
    '오늘 고마웠던 일 하나 짧게 녹음해서 남겨봐!'),
  suggestion('recording_02', 'recording', 'soft', ['recording_available'],
    '문자로 쓰기 쑥스러운 한마디를 녹음으로 전해보는 건 어때?'),
  suggestion('recording_03', 'recording', 'soft', ['recording_available'],
    '상대방 이름 한번 부르고 안부 남기는 것도 좋겠는데?'),
  suggestion('recording_04', 'recording', 'soft', ['recording_available'],
    '지금 기분을 한 문장으로 녹음해두면 나중에 들어도 재밌겠다'),
  suggestion('recording_05', 'recording', 'active', ['recording_available'],
    '둘만 아는 유행어나 말버릇을 녹음으로 남겨봐!'),
  suggestion('recording_06', 'recording', 'active', ['recording_available'],
    '상대방에게 가장 먼저 하고 싶은 말을 목소리로 남겨봐!'),
  suggestion('recording_07', 'recording', 'soft', ['recording_available'],
    '짧게 흥얼거린 노래 한 소절을 보내도 귀여울 것 같은데?'),
  suggestion('recording_08', 'recording', 'soft', ['recording_available'],
    '바쁜 날엔 긴 이야기 대신 짧은 목소리 하나 남기는 거 어때?'),
  suggestion('recording_09', 'recording', 'active', ['recording_available'],
    '상대방이 힘날 만한 한마디를 녹음해봐!'),
  suggestion('recording_10', 'recording', 'soft', ['recording_available'],
    '사랑한다고 녹음 하나 남겨볼까?'),
  suggestion('recording_11', 'recording', 'active', ['recording_available'],
    '상대방에게 고마웠던 점 하나 녹음해서 전해줘!'),
  suggestion('recording_12', 'recording', 'soft', ['recording_available'],
    '평소 자주 하는 인사를 녹음으로 남겨보는 건 어때?'),
  suggestion(
    'recording_13',
    'recording',
    'active',
    ['recording_available', 'morning'],
    '좋은 아침이라고 녹음 하나 남겨봐!',
  ),
  suggestion(
    'recording_14',
    'recording',
    'soft',
    ['recording_available', 'night'],
    '자기 전에 잘 자라고 녹음 하나 남겨볼까?',
  ),

  suggestion(
    'weather_01',
    'card',
    'soft',
    ['outdoor_ok', 'daytime', 'card_missing'],
    '오늘 날씨가 괜찮다면 상대방에게 보여주고 싶은 바깥 장면을 찍어도 좋겠는데?',
  ),
  suggestion(
    'weather_02',
    'card',
    'soft',
    ['outdoor_ok', 'daytime', 'card_missing'],
    '햇빛 좋은 날엔 눈에 들어오는 그림자 하나 찍어볼까?',
  ),
  suggestion(
    'weather_03',
    'card',
    'soft',
    ['outdoor_ok', 'daytime', 'card_missing'],
    '걷다가 발견한 꽃이나 나무 한 장 보여주는 건 어때?',
  ),
  suggestion(
    'weather_04',
    'card',
    'soft',
    ['near_sunset', 'card_missing'],
    '곧 노을 질 시간인데 하늘빛 한 장 남겨볼까?',
    'sunset_card',
  ),
  suggestion(
    'weather_05',
    'card',
    'active',
    ['cloudy', 'card_missing'],
    '흐린 날과 어울리는 색으로 그림 하나 남겨봐!',
  ),
  suggestion(
    'weather_06',
    'card',
    'soft',
    ['rain_possible', 'card_missing'],
    '비가 오면 창밖 풍경 하나 찍어 올려도 예쁠 것 같은데?',
  ),
  suggestion(
    'weather_07',
    'card',
    'active',
    ['snow_possible', 'card_missing'],
    '눈이 오면 한 장 찍어봐!',
  ),
  suggestion('weather_08', 'together', 'soft', ['hot'],
    '더운 날엔 시원한 음료 하나씩 골라서 즐겨도 좋겠는데?'),
  suggestion('weather_09', 'together', 'active', ['cold'],
    '쌀쌀한 날엔 따뜻한 음료 마시면서 얘기하자!'),
  suggestion('weather_10', 'together', 'soft', ['rain_possible'],
    '비가 올 수 있는 날엔 실내에서 하고 싶은 거 없어?'),
  suggestion('weather_11', 'together', 'soft', ['snow_possible'],
    '눈이 오면 잠깐 보러 나가자고 해볼까?'),
  suggestion('weather_12', 'together', 'soft', ['outdoor_ok'],
    '날씨가 괜찮다면 잠깐 밖으로 나가 같은 하늘 한번 볼까?'),
  suggestion(
    'weather_13',
    'card',
    'active',
    ['outdoor_ok', 'daytime', 'card_missing'],
    '밖에서 발견한 예쁜 색 하나 찍어 올려봐!',
  ),
  suggestion(
    'weather_14',
    'card',
    'active',
    ['outdoor_ok', 'daytime', 'card_missing'],
    '꽃이나 나무를 찾아서 사진 한 장 남겨봐!',
  ),
  suggestion(
    'weather_15',
    'card',
    'active',
    ['outdoor_ok', 'daytime', 'card_missing'],
    '상대방에게 보여주고 싶은 하늘 한 장 찍어봐!',
  ),
  suggestion(
    'weather_16',
    'card',
    'active',
    ['near_sunset', 'card_missing'],
    '노을빛이 보이면 한 장 찍어서 상대방에게 보내봐!',
    'sunset_card',
  ),
  suggestion(
    'weather_17',
    'card',
    'soft',
    ['cloudy', 'card_missing'],
    '흐린 하늘을 보고 떠오르는 색 하나 그려볼까?',
  ),
  suggestion(
    'weather_18',
    'card',
    'active',
    ['rain_possible', 'card_missing'],
    '비가 오면 창문에 맺힌 빗방울 한 장 남겨봐!',
  ),
  suggestion(
    'weather_19',
    'card',
    'active',
    ['hot', 'card_missing'],
    '시원한 간식 하나 골라서 사진으로 보여줘!',
  ),
  suggestion(
    'weather_20',
    'recording',
    'soft',
    ['cold', 'recording_available'],
    '쌀쌀한 날엔 따뜻한 목소리 한마디 남겨볼까?',
  ),
] as const satisfies readonly CuratedProactiveSuggestion[];

validateCatalog(curatedProactiveSuggestionCatalog);

export class CuratedProactiveSuggestionSelector {
  readonly #catalog: readonly CuratedProactiveSuggestion[];

  constructor(
    catalog: readonly CuratedProactiveSuggestion[] =
      curatedProactiveSuggestionCatalog,
  ) {
    validateCatalog(catalog);
    this.#catalog = catalog;
  }

  select(
    context: CuratedProactiveSuggestionSelectionContext,
  ): SelectedCuratedProactiveSuggestion {
    validateSelectionContext(context);
    const eligible = this.#catalog.filter((entry) =>
      isCuratedProactiveSuggestionEligible(entry, context)
    );
    const dayNumber = utcDayNumber(context.localDate);
    const preferredTargetIndex = positiveModulo(
      dayNumber + stableHash(`${context.userId}|target`),
      targetOrder.length,
    );
    const target = resolveAvailableTarget(
      eligible,
      preferredTargetIndex,
    );
    const targetCandidates = eligible.filter((entry) =>
      entry.target === target
    );
    const preferredStyle: CuratedProactiveSuggestionStyle = positiveModulo(
        dayNumber + stableHash(`${context.userId}|style`),
        4,
      ) === 0
      ? 'active'
      : 'soft';
    const styledCandidates = targetCandidates.filter((entry) =>
      entry.style === preferredStyle
    );
    const candidates = styledCandidates.length > 0
      ? styledCandidates
      : targetCandidates;
    const index = stableHash(
      `${context.userId}|${context.localDate}|${target}|${preferredStyle}`,
    ) % candidates.length;
    const selected = candidates[index];

    if (selected === undefined) {
      throw new Error('curated proactive suggestion catalog is empty');
    }
    return {
      id: selected.id,
      target: selected.target,
      style: selected.style,
      conditions: selected.conditions,
      text: selected.text,
      kind: selected.kind,
    };
  }
}

export function isCuratedProactiveSuggestionEligible(
  suggestion: CuratedProactiveSuggestion,
  context: CuratedProactiveSuggestionSelectionContext,
): boolean {
  return suggestion.conditions.every((condition) =>
    matchesCondition(condition, context)
  );
}

function suggestion(
  id: string,
  target: CuratedProactiveSuggestionTarget,
  style: CuratedProactiveSuggestionStyle,
  conditions: readonly CuratedProactiveSuggestionCondition[],
  text: string,
  kind: ProactiveSuggestionKind = target === 'card'
    ? 'card_idea'
    : 'date_idea',
): CuratedProactiveSuggestion {
  return { id, target, style, conditions, text, kind };
}

function matchesCondition(
  condition: CuratedProactiveSuggestionCondition,
  context: CuratedProactiveSuggestionSelectionContext,
): boolean {
  const weather = context.weather;
  switch (condition) {
    case 'always':
      return true;
    case 'card_missing':
      return !context.hasCardToday;
    case 'recording_available':
      return context.recordingAvailable;
    case 'morning':
      return context.localHour >= 5 && context.localHour < 12;
    case 'daytime':
      return context.localHour >= 8 && context.localHour < 18;
    case 'night':
      return context.localHour >= 21 || context.localHour < 5;
    case 'outdoor_ok':
      return weather !== null
        && weather.precipitationPossible === false
        && (
          weather.condition === 'clear'
          || weather.condition === 'partly_cloudy'
        )
        && (
          weather.apparentTemperatureC === null
          || (
            weather.apparentTemperatureC > 3
            && weather.apparentTemperatureC < 33
          )
        );
    case 'near_sunset':
      return weather?.nearSunset === true;
    case 'cloudy':
      return weather?.condition === 'cloudy';
    case 'rain_possible':
      return weather !== null
        && weather.condition !== 'snow_possible'
        && (
          weather.condition === 'rain_possible'
          || weather.precipitationPossible
        );
    case 'snow_possible':
      return weather?.condition === 'snow_possible';
    case 'hot':
      return weather !== null
        && (
          weather.condition === 'hot'
          || (weather.apparentTemperatureC ?? -Infinity) >= 33
        );
    case 'cold':
      return weather !== null
        && (
          weather.condition === 'cold'
          || (weather.apparentTemperatureC ?? Infinity) <= 3
        );
  }
}

function resolveAvailableTarget(
  eligible: readonly CuratedProactiveSuggestion[],
  preferredTargetIndex: number,
): CuratedProactiveSuggestionTarget {
  for (let offset = 0; offset < targetOrder.length; offset += 1) {
    const target = targetOrder[
      (preferredTargetIndex + offset) % targetOrder.length
    ];
    if (
      target !== undefined
      && eligible.some((entry) => entry.target === target)
    ) {
      return target;
    }
  }
  throw new Error('no eligible curated proactive suggestion');
}

function validateSelectionContext(
  context: CuratedProactiveSuggestionSelectionContext,
): void {
  const userId = context.userId.trim();
  if (userId.length === 0 || userId.length > 160) {
    throw new RangeError('user id must contain 1 to 160 characters');
  }
  utcDayNumber(context.localDate);
  if (
    !Number.isInteger(context.localHour)
    || context.localHour < 0
    || context.localHour > 23
  ) {
    throw new RangeError('local hour must be between 0 and 23');
  }
}

function validateCatalog(
  catalog: readonly CuratedProactiveSuggestion[],
): void {
  if (catalog.length === 0) {
    throw new Error('curated proactive suggestion catalog must not be empty');
  }
  const ids = new Set<string>();
  for (const entry of catalog) {
    if (!/^(?:together|card|recording|weather)_\d{2}$/.test(entry.id)) {
      throw new Error(`invalid curated proactive suggestion id: ${entry.id}`);
    }
    if (ids.has(entry.id)) {
      throw new Error(`duplicate curated proactive suggestion id: ${entry.id}`);
    }
    ids.add(entry.id);
    if (
      entry.text.trim().length === 0
      || entry.text !== entry.text.trim()
      || entry.text.length > 100
      || entry.text.includes('\ubbf8\uc158')
    ) {
      throw new Error(`invalid curated proactive suggestion text: ${entry.id}`);
    }
    if (entry.conditions.length === 0) {
      throw new Error(`missing curated suggestion conditions: ${entry.id}`);
    }
    if (
      entry.target === 'card'
      && (
        !entry.conditions.includes('card_missing')
        || (entry.kind !== 'card_idea' && entry.kind !== 'sunset_card')
      )
    ) {
      throw new Error(`invalid curated card suggestion: ${entry.id}`);
    }
    if (
      entry.target === 'recording'
      && !entry.conditions.includes('recording_available')
    ) {
      throw new Error(`invalid curated recording suggestion: ${entry.id}`);
    }
    if (
      entry.kind === 'sunset_card'
      && !entry.conditions.includes('near_sunset')
    ) {
      throw new Error(`invalid curated sunset suggestion: ${entry.id}`);
    }
  }
}

function utcDayNumber(localDate: string): number {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(localDate);
  if (match === null) {
    throw new RangeError('local date must use YYYY-MM-DD');
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const timestamp = Date.UTC(year, month - 1, day);
  const normalized = new Date(timestamp).toISOString().slice(0, 10);
  if (normalized !== localDate) {
    throw new RangeError('local date must be valid');
  }
  return Math.floor(timestamp / 86_400_000);
}

function stableHash(value: string): number {
  let hash = 0x811c9dc5;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

function positiveModulo(value: number, divisor: number): number {
  return ((value % divisor) + divisor) % divisor;
}
