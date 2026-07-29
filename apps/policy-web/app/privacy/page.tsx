import type { Metadata } from "next";
import { DocumentShell } from "../_components/document-shell";
import { PolicyDraftNotice } from "../_components/policy-draft-notice";

export const metadata: Metadata = {
  title: "개인정보처리방침",
};

export default function PrivacyPage() {
  return (
    <DocumentShell
      title="개인정보처리방침"
      description="단짠이 어떤 정보를 왜 처리하고, 언제 지우는지 실제 서비스 동작을 기준으로 정리한 초안입니다."
    >
      <PolicyDraftNotice
        id="privacy-status"
        detail="아래 내용은 앱 코드, 데이터베이스와 서버 기능에서 확인된 현재 처리 흐름입니다."
      />

      <section className="policy-section" aria-labelledby="privacy-data">
        <h2 id="privacy-data">현재 처리하는 정보</h2>
        <dl className="policy-definition-list">
          <div>
            <dt>계정과 프로필</dt>
            <dd>
              로그인 제공자 식별자, 서비스 사용자 ID, 닉네임과 생일을 로그인,
              프로필 표시, 온보딩과 기본 생일 일정에 사용합니다. Apple
              로그인은 최초 로그인 때 Apple이 제공하는 이메일과 이름을
              포함할 수 있습니다.
            </dd>
          </div>
          <div>
            <dt>커플 연결과 공유 기록</dt>
            <dd>
              초대 코드, 두 사용자 ID, 만난 날, 연결·해제·차단 상태와 카드,
              사진, 그림, 글, 질문·답변, 녹음, 캐릭터, 공유 일정을 커플 기능
              제공과 접근 제어에 사용합니다.
            </dd>
          </div>
          <div>
            <dt>AI 기능</dt>
            <dd>
              AI 동의 상태, 질문과 답변, 기억 후보와 확인·거절 결정, 생성된
              피드백·질문·추천, 모델과 처리 상태 등의 실행 진단 정보를
              개인화 기능, 재시도와 품질 확인에 사용합니다.
            </dd>
          </div>
          <div>
            <dt>알림과 안전</dt>
            <dd>
              기기 알림 토큰과 설정, 발송 결과, 안전 이용 약속 동의, 신고
              대상·사유·선택적 설명·처리 기록, 차단 관계를 알림 전달과 신고
              검토, 재연결 제한에 사용합니다.
            </dd>
          </div>
          <div>
            <dt>기기에 남는 정보</dt>
            <dd>
              인증 세션, 개인 설정, AI 추천 캐시와 노출 상태, 미완료 녹음,
              위젯 표시 데이터를 로그인 유지, 복구, 성능과 위젯 제공에
              사용합니다.
            </dd>
          </div>
        </dl>
        <p>
          현재 앱에는 광고 SDK와 사용자 행동 분석 SDK가 포함되어 있지
          않습니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="privacy-ai-location">
        <h2 id="privacy-ai-location">AI와 위치 정보 처리</h2>
        <ul>
          <li>
            AI 기능에 동의한 경우 질문·답변과 사용자가 확인한 기억을 Google
            Gemini에 필요한 범위에서 전달합니다.
          </li>
          <li>
            Gemini에는 실제 사용자 ID와 닉네임 대신
            <code>partner_a</code>, <code>partner_b</code> 구분값을
            전달합니다.
          </li>
          <li>
            AI 실행 진단에는 프롬프트 원문을 저장하지 않고 모델, 버전, 토큰
            수, 지연 시간과 처리·오류 상태를 기록합니다.
          </li>
          <li>
            선제 추천을 만들 때만 기기의 저정밀 현재 위치를 한 번
            조회합니다. 좌표는 소수 둘째 자리로 반올림해 Open-Meteo에
            전달하며 단짠 데이터베이스에는 저장하지 않습니다.
          </li>
          <li>
            AI가 만든 문구에는 앱 안에서 AI 표시와 신고할 수 있는 경로를
            제공합니다.
          </li>
        </ul>
      </section>

      <section className="policy-section" aria-labelledby="privacy-processors">
        <h2 id="privacy-processors">외부 서비스로 전달되는 정보</h2>
        <dl className="policy-definition-list">
          <div>
            <dt>Supabase</dt>
            <dd>
              인증, Database, 비공개 Storage, 실시간 동기화와 서버 기능을
              제공합니다.
            </dd>
          </div>
          <div>
            <dt>Kakao·Apple</dt>
            <dd>
              소셜 로그인에 필요한 인증 요청과 토큰을 처리합니다. Apple
              로그인 계정 삭제 시 Apple 권한 철회도 처리합니다.
            </dd>
          </div>
          <div>
            <dt>Google Gemini</dt>
            <dd>
              질문, 답변, 확인된 기억과 최근 문맥을 받아 기억 후보, 피드백,
              질문과 추천을 생성합니다.
            </dd>
          </div>
          <div>
            <dt>Firebase Cloud Messaging</dt>
            <dd>
              기기 토큰, 알림 문구와 앱 이동 정보를 받아 Android와 iOS
              알림을 전달합니다.
            </dd>
          </div>
          <div>
            <dt>Open-Meteo</dt>
            <dd>
              반올림한 저정밀 좌표를 받아 현재 날씨와 일몰 맥락을
              제공합니다.
            </dd>
          </div>
        </dl>
        <p>
          각 처리자의 이전 국가·리전, 이전 방법과 보유 기간은 실제 운영
          계약을 확인한 뒤 최종본에 표시합니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="privacy-retention">
        <h2 id="privacy-retention">보관과 삭제</h2>
        <ul>
          <li>
            계정과 공유 기록은 서비스 제공 기간 동안 비공개 저장소에
            보관합니다.
          </li>
          <li>
            일반 커플 연결 해제 후 공유 데이터는 30일 동안 읽기 전용으로
            보관하며, 같은 두 사람이 이 기간 안에 명시적으로 재연결하면
            복원할 수 있습니다.
          </li>
          <li>
            상대방을 차단하면 연결이 즉시 해제되고 공유 데이터는 양쪽에서
            숨겨집니다. 차단을 해제해도 자동으로 다시 연결되지는 않습니다.
          </li>
          <li>
            30일 보관기간이 끝나거나 연결 해제 후 즉시 삭제를 요청하면
            관계형 데이터가 삭제되고 파일은 서버 정리 큐에서 삭제됩니다.
          </li>
          <li>
            계정을 삭제하면 사용자가 속한 커플의 공유 데이터와 계정을
            삭제하고 기기의 관련 캐시·임시 파일·위젯 데이터도 정리합니다.
          </li>
        </ul>
        <p>
          AI 실행, 알림 발송 진단과 신고 검토 기록의 구체적인 보관기간은
          운영 기준이 확정된 뒤 최종본에 표시합니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="privacy-rights">
        <h2 id="privacy-rights">이용자의 선택과 권리</h2>
        <ul>
          <li>앱 설정에서 프로필과 알림 설정을 확인하거나 변경할 수 있습니다.</li>
          <li>
            AI 탭에서 AI 학습 상태와 기억 후보를 확인하고 맞는지 검토할 수
            있습니다.
          </li>
          <li>
            커플 연결을 해제하거나 보관 중인 공유 데이터를 즉시 삭제할 수
            있습니다.
          </li>
          <li>
            설정의 계정 메뉴에서 계정과 관련 공유 데이터를 영구 삭제할 수
            있습니다.
          </li>
        </ul>
        <p>
          개인정보 문의와 앱을 사용할 수 없는 경우의 권리 행사 방법은 공개
          이메일과 본인 확인 절차가 확정된 뒤 이 문서에 추가합니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="privacy-security">
        <h2 id="privacy-security">정보를 보호하는 방법</h2>
        <p>
          서버 데이터는 사용자와 커플 관계를 확인하는 접근 제어를 적용하고,
          사진·녹음·그림 파일은 비공개 저장소에 보관합니다. 계정 삭제와
          주요 데이터 정리는 일반 사용자에게 직접 열리지 않은 서버 전용
          기능으로 처리합니다.
        </p>
      </section>
    </DocumentShell>
  );
}
