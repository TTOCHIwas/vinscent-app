# 홈 선제 추천 문구 카탈로그 v1

## 목적

홈 캐릭터가 커플에게 부담 없는 제안이나 짧은 미션을 건넨다. 추천은 일반적인 함께하기에 머물지 않고 카드와 녹음 기능을 자연스럽게 사용할 계기를 제공한다.

이 문서는 문구와 노출 조건을 검토하기 위한 초안이다. 아직 애플리케이션이나 서버에는 적용하지 않는다.

## 선택 원칙

- 이전 추천 이력은 조회하지 않으며 같은 문구의 재노출을 허용한다.
- 먼저 현재 상태에서 사용할 수 있는 문구만 남긴 뒤 날짜와 사용자 식별자를 이용해 안정적으로 하나를 고른다.
- 일반 제안, 카드, 녹음이 한쪽으로 쏠리지 않도록 대상 영역을 순환한다.
- 미션은 전체 노출의 약 20~25%로 제한한다.
- 날씨 문구는 날씨 정보가 있을 때만 후보가 된다.
- 날씨 문구는 매번 우선하지 않고 해당 조건에서 사용할 수 있는 후보군에 합류한다.
- 카드 문구는 요청한 사용자가 오늘 카드를 올리지 않았고 카드를 작성할 수 있을 때만 후보가 된다.
- 녹음 문구는 사용자가 공유 데이터를 편집할 수 있고 녹음 기능을 사용할 수 있을 때만 후보가 된다.
- 오전과 밤 문구는 커플의 현지 시각을 기준으로 제한한다.
- `outdoor_ok`는 강수 가능성이 없고 덥거나 춥지 않은 맑음 또는 구름 조금 상태를 뜻한다.
- 실제로 함께 있는지는 알 수 없으므로 대면 활동은 문장 안에서 조건형으로 표현한다.

## 조건 표기

| 조건 | 의미 |
|---|---|
| `always` | 별도 조건 없음 |
| `card_missing` | 오늘 내가 올린 카드가 없고 카드 작성 가능 |
| `recording_available` | 녹음 기능 사용 가능 |
| `morning` | 현지 시각 오전 |
| `daytime` | 현지 시각 낮 |
| `night` | 현지 시각 늦은 저녁 이후 |
| `outdoor_ok` | 부담 없이 바깥 활동을 제안할 수 있는 날씨 |
| `near_sunset` | 노을 시간대에 가까움 |
| `cloudy` | 흐림 |
| `rain_possible` | 비 가능성 있음 |
| `snow_possible` | 눈 가능성 있음 |
| `hot` | 체감온도가 높은 상태 |
| `cold` | 체감온도가 낮은 상태 |

## 일반 제안

| ID | 조건 | 문구 |
|---|---|---|
| `together_s01` | `always` | 둘이 좋아하는 간식 하나 골라 천천히 나눠 먹어보자!     |
| `together_s02` | `always` | 서로 요즘 자주 듣는 노래 서로 들려주기하자!         |
| `together_s03` | `always` | 잠깐이라도 오늘 있었던 일 하나씩 꺼내 이야기해보는 건 어때? |
| `together_s04` | `always` | 사진첩에서 예전 사진 하나 골라 같이 다시볼까?   |
| `together_s05` | `always` | X |
| `together_s06` | `always` | 각자 개인적인 시간을 갖는것도 필요해         |
| `together_s07` | `always` | X |
| `together_s08` | `always` | 둘이 다음에 가보고 싶은 곳을 하나씩 얘기해보자!  |
| `together_s09` | `always` | 카페가서 서로 좋아하는 음료 소개 해주기 어떄?      |
| `together_s10` | `always` | 오늘 가장 웃겼던 순간을 서로 하나씩 들려주는 건 어때? |
| `together_s11` | `always` | 함께 보고 싶었던 영화나 영상 볼까?   |
| `together_s12` | `always` | 지금 서로에게 필요한 게 휴식인지 대화인지 물어봐도 좋겠다 |

## 일반 미션

| ID | 조건 | 문구 |
|---|---|---|
| `together_m01` | `always` | 오늘의 작은 미션, 상대방을 웃게 할 말 하나 건네기! |
| `together_m02` | `always` | 오늘의 작은 미션, 둘이 먹고 싶은 메뉴를 동시에 말해보기! |
| `together_m03` | `always` | 둘만의 짧은 미션, 서로에게 노래 한 곡씩 추천하기! |
| `together_m04` | `always` | 오늘은 이것만 해보기, 휴대전화를 잠깐 내려두고 이야기하기! |
| `together_m05` | `always` | 가벼운 미션 하나, 상대방의 좋은 점을 바로 하나 말해주기! |
| `together_m06` | `always` | 오늘의 작은 미션, 둘만 아는 말투로 오늘 하루를 요약하기! |

## 카드 제안

| ID | 조건 | 문구 |
|---|---|---|
| `card_s01` | `card_missing` | 오늘 상대방에게 보여주고 싶은 장면이 있다면 카드로 한 장 남겨도 좋겠다 |
| `card_s02` | `card_missing` | 오늘 가장 마음에 남은 순간 하나를 사진이나 그림으로 남기는 건 어때? |
| `card_s03` | `card_missing` | 지금 눈에 들어오는 색 하나를 골라 짧은 그림으로 남겨봐! |
| `card_s04` | `card_missing` | 평범해서 지나칠 뻔한 오늘의 한 장면을 카드에 담아볼까? |
| `card_s05` | `card_missing` | 오늘 기억하고 싶은 장면을 사진으로 남겨보는 건 어때? |
| `card_s06` | `card_missing` | 지금 기분을 닮은 낙서 하나 그려봐!    |
| `card_s07` | `card_missing` | 상대방이 보면 웃을 것 같은 장면을 카드로 살짝 보내도 재밌겠다! |
| `card_s08` | `card_missing` | X |
| `card_s09` | `card_missing` | 하루가 끝나기 전에 오늘을 떠올리게 하는 물건 하나를 찍어봐! |
| `card_s10` | `card_missing` | 상대방에게 보여주고 싶은 사진을 찍어올려봐!           |
| `card_s11` | `card_missing` | X |
| `card_s12` | `card_missing` | 특별한 일이 없어도 오늘의 평범함을 카드 한 장으로 남겨봐  |

## 카드 미션

| ID | 조건 | 문구 |
|---|---|---|
| `card_m01` | `card_missing` | 오늘의 작은 미션, 상대방에게 보여주고 싶은 장면 한 장 올리기! |
| `card_m02` | `card_missing` | 오늘은 이것만 해보기, 지금 가장 가까이에 있는 귀여운 것 찍기! |
| `card_m03` | `card_missing` | 가벼운 미션 하나, 오늘 먹은 것 중 제일 맛있었던 장면 남기기! |
| `card_m04` | `card_missing` | 오늘의 작은 미션, 지금 기분을 세 가지 색으로만 그려보기! |
| `card_m05` | `card_missing` | 둘만의 짧은 미션, 상대방이 맞히게 오늘을 그림으로 표현하기! |
| `card_m06` | `card_missing` | 오늘은 사진첩에서 웃음 나는 사진 하나 골라 카드로 올리기! |
| `card_m07` | `card_missing` | 오늘 함께 있다면 작은 미션, 서로 사진 한 장씩 찍어주기! |
| `card_m08` | `card_missing` | 오늘의 작은 미션, 둘만 알아볼 수 있는 낙서 하나 카드로 남기기! |

## 녹음 제안

| ID | 조건 | 문구 |
|---|---|---|
| `recording_s01` | `recording_available` | 오늘 고마웠던 일 하나를 짧은 목소리로 남겨도 좋겠다 |
| `recording_s02` | `recording_available` | 문자로 쓰기 쑥스러운 한마디를 녹음으로 전해보는 건 어때? |
| `recording_s03` | `recording_available` | 상대방 이름을 한번 부르고 짧게 안부를 남기는 것도 좋겠는데?   |
| `recording_s04` | `recording_available` | X |
| `recording_s05` | `recording_available` | 지금 기분을 한 문장으로 녹음해두면 나중에 들어도 재밌겠다 |
| `recording_s06` | `recording_available` | 둘만 아는 유행어나 말버릇을 녹음으로 남겨봐! |
| `recording_s07` | `recording_available` | 오늘 상대방에게 가장 먼저 하고 싶은 말을 목소리로 남겨봐!  |
| `recording_s08` | `recording_available` | 짧게 흥얼거린 노래 한 소절을 녹음으로 보내도 귀여울 것 같은데?   |
| `recording_s09` | `recording_available` | 바쁜 날에는 긴 이야기 대신 짧은 목소리 하나 남기는거어때?   |
| `recording_s10` | `recording_available` | 상대방이 힘날 만한 한마디를 평소 말투 그대로 녹음해보는 건 어때? |

## 녹음 미션

| ID | 조건 | 문구 |
|---|---|---|
| `recording_m01` | `recording_available` | 오늘의 작은 미션, 사랑한다는 말을 평소 말투 그대로 녹음하기! |
| `recording_m02` | `recording_available` | 둘만의 짧은 미션, 상대방 이름을 부르고 안부 한마디 남기기! |
| `recording_m03` | `recording_available` | X |
| `recording_m04` | `recording_available` | 오늘의 작은 미션, 서로만 아는 유행어 하나 녹음으로 남기기! |
| `recording_m05` | `recording_available` | 가벼운 미션 하나, 상대방에게 고마웠던 점 하나 말해주기! |
| `recording_m06` | `recording_available` | 오늘의 작은 미션, 한 문장으로 지금 기분을 녹음하기! |
| `recording_m07` | `recording_available`, `morning` | 아침의 작은 미션, 좋은 아침과 함께 응원 한마디 남기기! |
| `recording_m08` | `recording_available`, `night` | 자기 전 작은 미션, 잘 자라는 말 뒤에 애칭 한 번 불러주기! |

## 날씨 연계 제안

| ID | 조건 | 문구 |
|---|---|---|
| `weather_s01` | `outdoor_ok`, `daytime`, `card_missing` | 오늘 날씨가 괜찮다면 상대방에게 보여주고 싶은 바깥 장면을 찍어도 좋겠다 |
| `weather_s02` | `outdoor_ok`, `daytime`, `card_missing` | 햇빛이 좋은 날엔 눈에 들어오는 그림자 하나를 카드로 남겨도 예쁘겠다 |
| `weather_s03` | `outdoor_ok`, `daytime`, `card_missing` | 걷다가 발견한 꽃이나 나무 한 장을 상대방에게 보여주는 건 어때? |
| `weather_s04` | `near_sunset`, `card_missing` | 곧 노을 질 시간인데 하늘빛 한 장을 카드로 남겨도 예쁘겠다 |
| `weather_s05` | `cloudy`, `card_missing` | 흐린 날의 차분한 색을 사진이나 그림으로 담아봐! |
| `weather_s06` | `rain_possible`, `card_missing` | 비오는 날 창 밖을 찍어올려도 이쁠 것 같은데?        |
| `weather_s07` | `snow_possible`, `card_missing` | 눈 내리는 거 찍자!   |
| `weather_s08` | `hot` | 더운 날엔 시원한 음료 하나씩 골라 느긋하게 즐겨도 좋겠는데?   |
| `weather_s09` | `cold` | 쌀쌀한 날엔 따뜻한 음료 먹으면서 얘기하자!    |
| `weather_s10` | `rain_possible` | 비가 올 수 있는 날 실내에서 하고싶은 거 없어?   |
| `weather_s11` | `snow_possible`, `recording_available` | 눈 내리는 거 보러가는 건 어때?        |
| `weather_s12` | `outdoor_ok` | 날씨가 괜찮다면 잠깐 밖으로 나가 같은 하늘을 한번 올려다봐도 좋겠다 |

## 날씨 연계 미션

| ID | 조건 | 문구 |
|---|---|---|
| `weather_m01` | `outdoor_ok`, `daytime`, `card_missing` | 오늘의 작은 미션, 밖에서 발견한 예쁜 색 하나 찍어 올리기! |
| `weather_m02` | `outdoor_ok`, `daytime`, `card_missing` | 오늘은 이것만 해보기, 꽃이나 나무를 찾아 사진 한 장 남기기! |
| `weather_m03` | `outdoor_ok`, `daytime`, `card_missing` | 가벼운 미션 하나, 상대방에게 보여주고 싶은 하늘 한 장 찍기! |
| `weather_m04` | `near_sunset`, `card_missing` | 노을빛이 보이면 작은 미션, 서로 다른 자리에서 하늘 남기기! |
| `weather_m05` | `cloudy`, `card_missing` | 오늘의 작은 미션, 흐린 날과 어울리는 색으로 그림 하나 남기기! |
| `weather_m06` | `rain_possible`, `card_missing` | 비가 온다면 작은 미션, 창문에 맺힌 빗방울 한 장 남기기! |
| `weather_m07` | `hot`, `card_missing` | 더운 날의 작은 미션, 서로 고른 시원한 간식 사진으로 보여주기! |
| `weather_m08` | `cold`, `recording_available` | 쌀쌀한 날의 작은 미션, 상대방이 따뜻해질 목소리 한마디 남기기! |

## 검토할 항목

- 캐릭터 말투로 자연스러운가
- 행동을 지나치게 강요하지 않는가
- 카드와 녹음 중 어느 한 기능으로 치우치지 않는가
- 실제로 알 수 없는 날씨나 함께 있는 상황을 단정하지 않는가
- 비슷한 어미가 연속해서 피로하게 느껴지지 않는가
- 미션이 일반 제안과 구분되면서도 부담스럽지 않은가
