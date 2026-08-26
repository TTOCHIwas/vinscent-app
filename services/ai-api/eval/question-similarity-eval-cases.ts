export interface QuestionSimilarityEvaluationComparison {
  question: string;
  relation: QuestionSimilarityRelation;
}

export type QuestionSimilarityRelation =
  | 'near_duplicate'
  | 'topic_overlap'
  | 'distinct';

export interface QuestionSimilarityEvaluationScenario {
  id: string;
  candidate: string;
  comparisons: QuestionSimilarityEvaluationComparison[];
}

export function createQuestionSimilarityEvaluationScenarios():
  QuestionSimilarityEvaluationScenario[] {
  return [
    scenario('movie', '다음 주말에 둘이 같이 해보고 싶은 영화는 뭐야?', [
      nearDuplicate('둘이 함께 보고 싶은 작품은 어떤 거야?'),
      topicOverlap('주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?'),
      distinct('둘이 함께 먹고 싶은 메뉴는 뭐야?'),
      distinct('쉬는 날에는 집과 밖 중 어디가 더 편해?'),
    ]),
    scenario('travel', '둘이 여행을 간다면 가장 가고 싶은 곳은 어디야?', [
      nearDuplicate('함께 떠나고 싶은 여행지는 어디야?'),
      topicOverlap('해외여행과 국내여행 중 어느 쪽을 더 좋아해?'),
      distinct('둘이 볼 영화를 고를 때 가장 중요한 건 뭐야?'),
      distinct('평소 아침에 가장 먼저 하는 일은 뭐야?'),
    ]),
    scenario('gift', '기념일에 받고 싶은 선물은 어떤 거야?', [
      nearDuplicate('기념일에 어떤 선물을 받고 싶어?'),
      topicOverlap('실용적인 선물과 추억을 만드는 선물 중 뭐가 더 좋아?'),
      distinct('서운한 일이 생기면 어떻게 이야기하는 게 편해?'),
      distinct('같이 먹으러 가고 싶은 음식은 뭐야?'),
    ]),
    scenario('rest', '쉬는 날에는 어떻게 보내야 가장 편해?', [
      nearDuplicate('휴일을 어떻게 보내야 가장 편해?'),
      topicOverlap('피곤할 때 집에서 충전하는 방법은 뭐야?'),
      distinct('둘이 사진을 찍을 때 어떤 분위기를 좋아해?'),
      distinct('여행지에서 꼭 먹어보고 싶은 음식은 뭐야?'),
    ]),
    scenario('food', '둘이 같이 먹고 싶은 메뉴는 뭐야?', [
      nearDuplicate('함께 먹고 싶은 음식은 뭐야?'),
      topicOverlap('고기와 해산물 중 외식할 때 더 끌리는 건 뭐야?'),
      distinct('비 오는 날에는 어떤 데이트가 좋아?'),
      distinct('서로에게 듣고 싶은 말은 뭐야?'),
    ]),
    scenario('repair', '서운한 일이 생기면 어떤 방식으로 풀고 싶어?', [
      nearDuplicate('서운할 때 어떻게 풀고 싶어?'),
      topicOverlap('사과를 받을 때 가장 중요하게 느끼는 건 뭐야?'),
      distinct('둘이 떠나고 싶은 여행지는 어디야?'),
      distinct('함께 듣고 싶은 노래는 어떤 곡이야?'),
    ]),
    scenario('affection', '어떤 순간에 사랑받는다고 느껴?', [
      nearDuplicate('사랑받는다고 느끼는 때는 언제야?'),
      topicOverlap('상대의 애정 표현 중 가장 기분 좋은 건 뭐야?'),
      distinct('주말 약속은 미리 정하는 편이 좋아?'),
      distinct('영화관에서는 어느 자리를 좋아해?'),
    ]),
    scenario('goals', '둘이 앞으로 함께 이루고 싶은 목표는 뭐야?', [
      nearDuplicate('둘이 함께 이루고 싶은 건 뭐야?'),
      topicOverlap('커플 버킷리스트에 꼭 넣고 싶은 건 뭐야?'),
      distinct('오늘 저녁에 먹고 싶은 건 뭐야?'),
      distinct('사진을 꾸밀 때 어떤 색을 좋아해?'),
    ]),
    scenario('date_place', '데이트할 때 어떤 장소가 가장 좋아?', [
      nearDuplicate('둘이 자주 가고 싶은 데이트 공간은 어디야?'),
      topicOverlap('사람 많은 곳과 조용한 곳 중 어디에서 만나고 싶어?'),
      distinct('기념일 선물로 준비하고 싶은 건 뭐야?'),
      distinct('아침형과 저녁형 중 어느 쪽에 가까워?'),
    ]),
    scenario('routine', '둘이 함께 만들고 싶은 일상 습관은 뭐야?', [
      nearDuplicate('매일 같이 지키고 싶은 작은 루틴은 뭐야?'),
      topicOverlap('잠들기 전에 함께 하고 싶은 일은 뭐야?'),
      distinct('바다와 산 중 여행지로 어디가 좋아?'),
      distinct('서로에게 받고 싶은 선물은 뭐야?'),
    ]),
  ];
}

function scenario(
  id: string,
  candidate: string,
  comparisons: QuestionSimilarityEvaluationComparison[],
): QuestionSimilarityEvaluationScenario {
  return { id, candidate, comparisons };
}

function nearDuplicate(
  question: string,
): QuestionSimilarityEvaluationComparison {
  return { question, relation: 'near_duplicate' };
}

function topicOverlap(
  question: string,
): QuestionSimilarityEvaluationComparison {
  return { question, relation: 'topic_overlap' };
}

function distinct(question: string): QuestionSimilarityEvaluationComparison {
  return { question, relation: 'distinct' };
}
