import type { Metadata } from "next";
import { DocumentShell } from "../_components/document-shell";
import { policyRelease } from "../policy-release";

export const metadata: Metadata = {
  title: "안전 이용 약속",
};

export default function SafetyPage() {
  return (
    <DocumentShell
      title="안전 이용 약속"
      description="두 사람이 안심하고 기록을 나누기 위해 함께 지켜야 할 기준을 안내합니다."
      documentMeta={`시행일 ${policyRelease.effectiveDate}`}
    >
      <p className="document-version">
        현재 적용 버전 <strong>ugc-safety-v1</strong>
      </p>

      <section className="policy-section" aria-labelledby="safety-scope">
        <h2 id="safety-scope">모든 공유 콘텐츠에 적용돼요</h2>
        <p>
          카드, 사진, 그림, 텍스트, 답변, 녹음, 캐릭터와 일정처럼 단짠에서
          만들거나 공유하는 모든 내용에 이 약속이 적용됩니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="safety-rules">
        <h2 id="safety-rules">이런 내용은 나눌 수 없어요</h2>
        <ul>
          <li>상대방이나 다른 사람을 모욕하거나 괴롭히고 위협하는 내용</li>
          <li>특정 개인이나 집단에 대한 혐오 또는 차별을 조장하는 내용</li>
          <li>
            성적 착취, 동의 없는 성적 콘텐츠 또는 아동·청소년을 성적으로
            대상화하는 내용
          </li>
          <li>자해, 폭력, 위험 행동이나 불법 행위를 조장하는 내용</li>
          <li>다른 사람의 개인정보를 허락 없이 공개하거나 사칭하는 내용</li>
          <li>스팸, 악성 링크 등 서비스와 다른 이용자에게 피해를 주는 내용</li>
        </ul>
      </section>

      <section className="policy-section" aria-labelledby="safety-reporting">
        <h2 id="safety-reporting">불편한 내용은 신고하거나 차단할 수 있어요</h2>
        <p>
          앱 안의 신고 기능으로 카드, 답변, 녹음, 그림과 AI가 만든 내용을
          알릴 수 있습니다. 신고를 검토하는 데 필요한 범위에서 대상 내용의
          제한된 사본이 함께 보관될 수 있습니다.
        </p>
        <p>
          상대방을 차단하면 커플 연결이 해제되고 서로의 공유 데이터가
          보이지 않게 됩니다. 차단을 해제하더라도 자동으로 다시 연결되지는
          않습니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="safety-enforcement">
        <h2 id="safety-enforcement">신고된 내용은 확인 후 조치해요</h2>
        <p>
          신고 내용과 관련 기록을 확인한 뒤 필요한 경우 콘텐츠를 삭제하거나
          기능 또는 계정 이용을 제한할 수 있습니다. 모든 신고가 같은 조치로
          이어지는 것은 아니며, 허위 신고나 신고 기능의 반복적인 악용도
          제한될 수 있습니다.
        </p>
        <p>
          대표자 {policyRelease.operatorName}가 비공개 신고 채널을 확인하며,
          접수 후 {policyRelease.moderationInitialReviewDays}일 이내에 최초
          검토하는 것을 운영 목표로 합니다. 신체 안전이나 긴급한 위험이
          의심되는 신고는 먼저 확인합니다.
        </p>
        <p>
          미처리 신고는 검토가 끝날 때까지 보관합니다. 검토가 끝난 신고와
          관련 검토·운영 알림 기록은 검토일부터
          {" "}
          {policyRelease.reviewedSafetyReportRetention} 동안 보관한 뒤
          삭제합니다. 신고자가 계정을 먼저 삭제하면 현재 계정 삭제 흐름에
          따라 함께 삭제될 수 있습니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="safety-consent">
        <h2 id="safety-consent">동의한 뒤 기록을 공유할 수 있어요</h2>
        <p>
          단짠에서 공유 콘텐츠를 만들거나 올리려면 현재 안전 이용 약속을
          확인하고 동의해야 합니다. 기준이 실질적으로 변경되면 새 버전을
          안내하고 다시 동의를 받습니다.
        </p>
      </section>
    </DocumentShell>
  );
}
