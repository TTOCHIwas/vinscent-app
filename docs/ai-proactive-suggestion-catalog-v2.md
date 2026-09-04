# 홈 선제 추천 문구 카탈로그 v2

## 목적

홈 캐릭터가 친한 친구처럼 짧은 제안을 건넨다. 문구는 사용자가 혼자 먼저 시작할 수 있어야 하며 상대방도 같은 추천을 받았다고 가정하지 않는다.

카드와 녹음 기능은 사용법을 설명하지 않고 자연스럽게 사용하도록 권한다. 사용자에게 `미션`이라는 이름이나 별도 유형은 보여주지 않는다.

## 선택 원칙

- 사람이 검수한 문구 중 현재 조건에 맞는 항목 하나를 선택한다.
- 이전 추천 이력은 조회하지 않으며 같은 문구의 재노출을 허용한다.
- 일반 활동, 카드, 녹음 중 한 영역에만 쏠리지 않도록 날짜를 기준으로 후보 영역을 순환한다.
- `active` 문구는 약 20~25%만 선택해 직접적인 권유가 연속되지 않도록 한다.
- `soft`와 `active`는 내부 선택용 정보이며 사용자에게 표시하지 않는다.
- 카드 문구는 오늘 내가 올린 카드가 없고 카드를 작성할 수 있을 때만 선택한다.
- 녹음 문구는 공유 데이터를 편집할 수 있고 녹음 기능을 사용할 수 있을 때만 선택한다.
- 날씨 문구는 실제 날씨 정보가 있을 때만 선택한다.
- 대면 여부를 알 수 없으므로 함께 있어야 가능한 행동은 조건형으로 말한다.
- 한쪽에 휴식, 다른 쪽에 대화처럼 모순될 수 있는 관계 조언은 하지 않는다.
- 문장은 짧은 반말로 쓰고 `해봐!`, `하자!`, `해볼까?`, `어때?`, `좋겠는데?` 정도로 가볍게 권한다.

## 조건 표기

| 조건 | 의미 |
|---|---|
| `always` | 별도 조건 없음 |
| `card_missing` | 오늘 내가 올린 카드가 없고 카드 작성 가능 |
| `recording_available` | 녹음 기능 사용 가능 |
| `morning` | 현지 시각 오전 |
| `daytime` | 현지 시각 낮 |
| `night` | 현지 시각 늦은 저녁 이후 |
| `outdoor_ok` | 강수 가능성이 없고 덥거나 춥지 않은 바깥 활동 가능 날씨 |
| `near_sunset` | 노을 시간대에 가까움 |
| `cloudy` | 흐림 |
| `rain_possible` | 비 가능성 있음 |
| `snow_possible` | 눈 가능성 있음 |
| `hot` | 체감온도가 높은 상태 |
| `cold` | 체감온도가 낮은 상태 |

## 함께하기

| ID | 스타일 | 조건 | 문구 |
|---|---|---|---|
| `together_01` | `active` | `always` | 같이 먹고 싶은 간식 하나 골라서 같이 먹자!     |
| `together_02` | `soft` | `always` | 요즘 자주 듣는 노래 하나 상대방에게 들려주는 건 어때? |
| `together_03` | `soft` | `always` | 오늘 있었던 일 하나 먼저 꺼내 얘기해볼까? |
| `together_04` | `soft` | `always` | 사진첩에서 예전 사진 하나 골라 같이 다시 볼까? |
| `together_05` | `active` | `always` | 둘이 다음에 가보고 싶은 곳을 하나씩 얘기해보자! |
| `together_06` | `soft` | `always` | 카페 가서 서로 좋아하는 음료 소개해주는 거 어때? |
| `together_07` | `active` | `always` | 오늘 가장 웃겼던 순간 하나 상대방에게 들려줘! |
| `together_08` | `active` | `always` | 같이 보고 싶은 영화나 영상 하나 골라서 보내봐! |
| `together_09` | `soft` | `always` | 상대방에게 지금 필요한 게 휴식인지 대화인지 물어봐도 좋겠는데? |
| `together_10` | `active` | `always` | 상대방 웃게 할 말 하나 해봐! |
| `together_11` | `soft` | `always` | 오늘 먹고 싶은 메뉴 하나 말하고 상대방 것도 물어볼까? |
| `together_12` | `active` | `always` | 둘만 아는 농담 하나 꺼내봐! |
| `together_13` | `soft` | `always` | 상대방의 좋은 점 하나 바로 말해주는 건 어때? |
| `together_14` | `active` | `always` | 상대방 말투로 오늘 하루를 한번 정리해봐! |
| `together_15` | `soft` | `always` | 다음에 같이 해보고 싶은 걸 하나 골라서 얘기해볼까? |
| `together_16` | `soft` | `always` | 서로 지금 먹고 싶은 거 하나씩 알려줘도 재밌겠는데? |

## 카드

| ID | 스타일 | 조건 | 문구 |
|---|---|---|---|
| `card_01` | `active` | `card_missing` | 상대방에게 보여주고 싶은 장면이 있으면 카드로 한 장 남겨봐! |
| `card_02` | `soft` | `card_missing` | 오늘 마음에 남은 순간 하나를 사진이나 그림으로 남겨볼까? |
| `card_03` | `active` | `card_missing` | 지금 눈에 들어오는 색 하나 골라서 짧게 그려봐! |
| `card_04` | `soft` | `card_missing` | 지나칠 뻔한 오늘의 한 장면을 카드에 담아볼까? |
| `card_05` | `active` | `card_missing` | 오늘 기억하고 싶은 장면 하나 사진으로 남겨봐! |
| `card_06` | `active` | `card_missing` | 지금 기분을 닮은 낙서 하나 그려봐! |
| `card_07` | `active` | `card_missing` | 상대방이 보면 웃을 것 같은 장면을 카드로 보내봐! |
| `card_08` | `active` | `card_missing` | 하루가 끝나기 전에 오늘을 떠올리게 하는 물건 하나 찍어봐! |
| `card_09` | `active` | `card_missing` | 상대방에게 보여주고 싶은 사진 하나 찍어 올려봐! |
| `card_10` | `soft` | `card_missing` | 특별한 일이 없어도 평범한 오늘을 카드 한 장으로 남겨볼까? |
| `card_11` | `active` | `card_missing` | 사진첩에서 웃음 나는 사진 하나 골라 카드로 올려봐! |
| `card_12` | `active` | `card_missing` | 상대방이 맞힐 수 있게 오늘을 그림으로 표현해봐! |
| `card_13` | `soft` | `card_missing` | 오늘 같이 있다면 상대방 사진 한 장 찍어주는 건 어때? |
| `card_14` | `active` | `card_missing` | 둘만 알아볼 수 있는 낙서 하나 카드로 남겨봐! |

## 녹음

| ID | 스타일 | 조건 | 문구 |
|---|---|---|---|
| `recording_01` | `active` | `recording_available` | 오늘 고마웠던 일 하나 짧게 녹음해서 남겨봐! |
| `recording_02` | `soft` | `recording_available` | 문자로 쓰기 쑥스러운 한마디를 녹음으로 전해보는 건 어때? |
| `recording_03` | `soft` | `recording_available` | 상대방 이름 한번 부르고 안부 남기는 것도 좋겠는데? |
| `recording_04` | `soft` | `recording_available` | 지금 기분을 한 문장으로 녹음해두면 나중에 들어도 재밌겠다 |
| `recording_05` | `active` | `recording_available` | 둘만 아는 유행어나 말버릇을 녹음으로 남겨봐! |
| `recording_06` | `active` | `recording_available` | 상대방에게 가장 먼저 하고 싶은 말을 목소리로 남겨봐! |
| `recording_07` | `soft` | `recording_available` | 짧게 흥얼거린 노래 한 소절을 보내도 귀여울 것 같은데? |
| `recording_08` | `soft` | `recording_available` | 바쁜 날엔 긴 이야기 대신 짧은 목소리 하나 남기는 거 어때? |
| `recording_09` | `active` | `recording_available` | 상대방이 힘날 만한 한마디를 녹음해봐! |
| `recording_10` | `soft` | `recording_available` | 사랑한다고 녹음 하나 남겨볼까? |
| `recording_11` | `active` | `recording_available` | 상대방에게 고마웠던 점 하나 녹음해서 전해줘! |
| `recording_12` | `soft` | `recording_available` | 평소 자주 하는 인사를 녹음으로 남겨보는 건 어때? |
| `recording_13` | `active` | `recording_available`, `morning` | 좋은 아침이라고 녹음 하나 남겨봐! |
| `recording_14` | `soft` | `recording_available`, `night` | 자기 전에 잘 자라고 녹음 하나 남겨볼까? |

## 날씨 연계

| ID | 스타일 | 조건 | 문구 |
|---|---|---|---|
| `weather_01` | `soft` | `outdoor_ok`, `daytime`, `card_missing` | 오늘 날씨가 괜찮다면 상대방에게 보여주고 싶은 바깥 장면을 찍어도 좋겠는데? |
| `weather_02` | `soft` | `outdoor_ok`, `daytime`, `card_missing` | 햇빛 좋은 날엔 눈에 들어오는 그림자 하나 찍어볼까? |
| `weather_03` | `soft` | `outdoor_ok`, `daytime`, `card_missing` | 걷다가 발견한 꽃이나 나무 한 장 보여주는 건 어때? |
| `weather_04` | `soft` | `near_sunset`, `card_missing` | 곧 노을 질 시간인데 하늘빛 한 장 남겨볼까? |
| `weather_05` | `active` | `cloudy`, `card_missing` | 흐린 날과 어울리는 색으로 그림 하나 남겨봐! |
| `weather_06` | `soft` | `rain_possible`, `card_missing` | 비가 오면 창밖 풍경 하나 찍어 올려도 예쁠 것 같은데? |
| `weather_07` | `active` | `snow_possible`, `card_missing` | 눈이 오면 한 장 찍어봐! |
| `weather_08` | `soft` | `hot` | 더운 날엔 시원한 음료 하나씩 골라서 즐겨도 좋겠는데? |
| `weather_09` | `active` | `cold` | 쌀쌀한 날엔 따뜻한 음료 마시면서 얘기하자! |
| `weather_10` | `soft` | `rain_possible` | 비가 올 수 있는 날엔 실내에서 하고 싶은 거 없어? |
| `weather_11` | `soft` | `snow_possible` | 눈이 오면 잠깐 보러 나가자고 해볼까? |
| `weather_12` | `soft` | `outdoor_ok` | 날씨가 괜찮다면 잠깐 밖으로 나가 같은 하늘 한번 볼까? |
| `weather_13` | `active` | `outdoor_ok`, `daytime`, `card_missing` | 밖에서 발견한 예쁜 색 하나 찍어 올려봐! |
| `weather_14` | `active` | `outdoor_ok`, `daytime`, `card_missing` | 꽃이나 나무를 찾아서 사진 한 장 남겨봐! |
| `weather_15` | `active` | `outdoor_ok`, `daytime`, `card_missing` | 상대방에게 보여주고 싶은 하늘 한 장 찍어봐! |
| `weather_16` | `active` | `near_sunset`, `card_missing` | 노을빛이 보이면 한 장 찍어서 상대방에게 보내봐! |
| `weather_17` | `soft` | `cloudy`, `card_missing` | 흐린 하늘을 보고 떠오르는 색 하나 그려볼까? |
| `weather_18` | `active` | `rain_possible`, `card_missing` | 비가 오면 창문에 맺힌 빗방울 한 장 남겨봐! |
| `weather_19` | `active` | `hot`, `card_missing` | 시원한 간식 하나 골라서 사진으로 보여줘! |
| `weather_20` | `soft` | `cold`, `recording_available` | 쌀쌀한 날엔 따뜻한 목소리 한마디 남겨볼까? |

## 검토 기준

- 캐릭터가 실제로 말하는 것처럼 짧고 자연스러운가
- 사용자가 혼자 먼저 시작할 수 있는가
- 상대방도 같은 추천을 받았다고 가정하지 않는가
- 기능 사용법을 설명하거나 광고하는 말투가 아닌가
- 직접 권하더라도 과제나 의무처럼 느껴지지 않는가
- 확인할 수 없는 날씨와 상황을 단정하지 않는가
- 비슷한 어미와 소재가 지나치게 몰려 있지 않은가
