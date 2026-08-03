import type { Metadata } from "next";
import { DocumentShell } from "../_components/document-shell";
import { policyRelease } from "../policy-release";

export const metadata: Metadata = {
  title: "계정 삭제 안내",
};

export default function AccountDeletionPage() {
  return (
    <DocumentShell
      title="계정 삭제 안내"
      description="단짠 계정과 관련 공유 데이터를 삭제하는 절차와 결과를 안내합니다."
      documentMeta={`시행일 ${policyRelease.effectiveDate}`}
    >
      <section className="policy-section" aria-labelledby="deletion-in-app">
        <h2 id="deletion-in-app">앱에서 바로 삭제하기</h2>
        <ol>
          <li>단짠 앱에서 설정을 엽니다.</li>
          <li>계정 메뉴를 선택합니다.</li>
          <li>계정 삭제를 선택하고 안내 내용을 확인합니다.</li>
          <li>삭제 확인을 완료하면 계정과 관련 데이터를 삭제합니다.</li>
        </ol>
        <p>
          Apple 로그인 계정은 계정 소유자를 확인하기 위해 Apple 로그인을
          다시 요청하며, 확인 후 Apple 로그인 권한을 먼저 철회합니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="deletion-scope">
        <h2 id="deletion-scope">삭제되는 정보</h2>
        <ul>
          <li>단짠 계정, 인증 식별자와 프로필</li>
          <li>커플 연결과 초대 관련 정보</li>
          <li>카드, 녹음, 답변, 캐릭터, 일정과 AI 데이터</li>
          <li>알림 토큰과 개인 알림 설정</li>
          <li>기기에 남은 AI 캐시, 캘린더 설정, 임시 녹음과 위젯 데이터</li>
        </ul>
        <p>
          사용자가 속한 커플의 공유 데이터도 함께 삭제되므로 상대방은 해당
          기록에 더 이상 접근할 수 없습니다. 상대방의 개인 계정 자체는
          삭제되지 않습니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="deletion-processing">
        <h2 id="deletion-processing">삭제가 처리되는 방식</h2>
        <p>
          확인이 끝나면 서버의 계정과 관계형 공유 데이터를 삭제합니다.
          사진, 녹음과 그림 파일은 누락을 막기 위해 서버 정리 큐에 등록해
          비동기로 삭제합니다. 삭제한 계정과 공유 데이터는 복구할 수
          없습니다.
        </p>
        <p>
          정상 이용 중 AI 실행과 알림 발송의 상세 진단은 생성 후
          {" "}
          {policyRelease.diagnosticRetentionDays}일 동안 보관할 수 있습니다.
          미처리 신고는 검토가 끝날 때까지, 검토가 끝난 신고와 관련 기록은
          검토일부터 {policyRelease.reviewedSafetyReportRetention} 동안
          보관할 수 있습니다. 이 기간이 지나기 전이라도 계정을 삭제하면
          현재 계정 삭제 흐름에 따라 함께 삭제됩니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="deletion-web">
        <h2 id="deletion-web">앱을 사용할 수 없는 경우</h2>
        <p>
          앱에 로그인할 수 없다면
          {" "}
          <a
            href={`mailto:${policyRelease.publicContactEmail}?subject=%EB%8B%A8%EC%A7%A0%20%EA%B3%84%EC%A0%95%20%EC%82%AD%EC%A0%9C%20%EC%9A%94%EC%B2%AD`}
          >
            {policyRelease.publicContactEmail}
          </a>
          으로 계정 삭제 요청을 보낼 수 있습니다. 단짠에서 사용한 로그인
          방식, 닉네임과 계정에 등록된 이메일을 함께 적어 주세요. 운영자가
          등록 이메일로 일회용 확인 코드를 보내고, 요청자가 같은 문의
          대화에서 코드를 확인하면 본인 확인이 완료됩니다. 확인 완료일부터
          {" "}
          {policyRelease.externalDeletionCompletionDays}일 이내에 계정과 관련
          데이터를 삭제하고 처리 결과를 같은 문의 대화로 알립니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="deletion-disconnect">
        <h2 id="deletion-disconnect">커플 연결 해제와는 달라요</h2>
        <p>
          일반 커플 연결 해제는 공유 데이터를 30일 동안 보관해 같은 두
          사람이 명시적으로 재연결할 때 복원할 수 있습니다. 계정 삭제는
          계정과 공유 데이터를 영구 삭제하므로 복원할 수 없습니다.
        </p>
      </section>
    </DocumentShell>
  );
}
