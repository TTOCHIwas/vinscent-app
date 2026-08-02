import type { Metadata } from "next";
import { DocumentShell } from "../_components/document-shell";
import { PolicyDraftNotice } from "../_components/policy-draft-notice";

export const metadata: Metadata = {
  title: "서비스 이용약관",
};

export default function TermsPage() {
  return (
    <DocumentShell
      title="서비스 이용약관"
      description="단짠의 계정, 커플 공유 기능과 안전한 이용 기준을 실제 서비스 동작에 맞춰 정리한 초안입니다."
    >
      <PolicyDraftNotice
        id="terms-status"
        detail="아래 내용은 현재 구현된 서비스 기능과 이용자 보호 경계를 설명합니다. 최종 계약 조항은 운영 정보와 법률 검토를 마친 뒤 확정합니다."
      />

      <section className="policy-section" aria-labelledby="terms-service">
        <h2 id="terms-service">서비스의 목적</h2>
        <p>
          단짠은 연결된 두 사람이 카드, 질문과 답변, 음성, 그림, 캐릭터와
          일정을 함께 만들고 돌아볼 수 있도록 돕는 커플 기록
          서비스입니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="terms-account">
        <h2 id="terms-account">계정과 커플 연결</h2>
        <ul>
          <li>단짠은 만 14세 이상인 이용자만 가입하고 이용할 수 있습니다.</li>
          <li>지원되는 소셜 로그인으로 본인 계정을 만들고 이용합니다.</li>
          <li>
            초대 코드를 통해 한 명의 상대방과 연결되며, 연결된 두 사람만
            커플 공유 기록에 접근할 수 있습니다.
          </li>
          <li>
            로그인 정보와 기기 접근 권한을 안전하게 관리하고, 다른 사람의
            계정을 허락 없이 사용해서는 안 됩니다.
          </li>
          <li>
            커플 연결을 해제하면 공유 기록은 30일 동안 보관되며, 즉시 삭제를
            선택하거나 계정 자체를 삭제할 수 있습니다.
          </li>
        </ul>
      </section>

      <section className="policy-section" aria-labelledby="terms-content">
        <h2 id="terms-content">공유 콘텐츠</h2>
        <p>
          이용자는 자신이 만들거나 적법하게 사용할 수 있는 콘텐츠만
          올려야 하며, 상대방을 포함한 다른 사람의 개인정보와 권리를
          존중해야 합니다. 서비스는 저장, 변환, 동기화, 알림과 위젯 등
          요청한 기능을 제공하는 데 필요한 범위에서 콘텐츠를 처리합니다.
        </p>
        <p>
          공유 콘텐츠에는 현재 버전의 안전 이용 약속이 적용됩니다. 괴롭힘,
          혐오·차별, 성적 착취, 위험·불법 행위 조장, 개인정보 무단 공개,
          사칭과 스팸 등은 허용되지 않습니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="terms-ai">
        <h2 id="terms-ai">AI 기능</h2>
        <ul>
          <li>
            AI 기능은 이용자가 동의한 범위의 질문·답변과 확인한 기억을
            바탕으로 질문, 피드백과 추천을 만듭니다.
          </li>
          <li>
            생성된 내용에는 AI 표시가 제공되며, 부정확하거나 예상과 다른
            내용이 포함될 수 있습니다.
          </li>
          <li>
            AI 답변은 의료, 법률, 재무 등 전문적인 판단을 대신하지 않으며
            관계의 지속 여부나 상대방의 의도를 확정하지 않습니다.
          </li>
          <li>
            부적절한 AI 결과는 앱에서 신고할 수 있고, 안전을 위해 일부
            요청이나 결과 제공이 제한될 수 있습니다.
          </li>
        </ul>
      </section>

      <section className="policy-section" aria-labelledby="terms-report-block">
        <h2 id="terms-report-block">신고와 차단</h2>
        <p>
          이용자는 공유 콘텐츠와 AI 결과를 신고할 수 있습니다. 신고된
          내용과 관련 기록을 검토한 뒤 콘텐츠 삭제, 기능 제한 또는 계정
          제한 등 필요한 조치를 할 수 있습니다.
        </p>
        <p>
          상대방을 차단하면 커플 연결이 즉시 해제되고 기존 공유 데이터는
          양쪽에서 보이지 않게 됩니다. 차단을 해제해도 이전 연결은
          자동으로 복원되지 않으며, 다시 연결하려면 두 사람이 새로 연결
          절차를 진행해야 합니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="terms-deletion">
        <h2 id="terms-deletion">이용 종료와 데이터 삭제</h2>
        <p>
          이용자는 언제든 커플 연결을 해제하거나 계정을 삭제할 수
          있습니다. 계정 삭제는 계정과 연결된 커플 공유 데이터를 영구
          삭제하며 복구할 수 없습니다. 구체적인 범위와 처리 흐름은 계정
          삭제 안내와 개인정보처리방침에서 확인할 수 있습니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="terms-changes">
        <h2 id="terms-changes">서비스 변경과 종료</h2>
        <p>
          안정성, 보안, 법령 또는 기능 개선을 위해 서비스를 변경하거나
          일부 기능을 제한할 수 있습니다. 이용자 권리나 의무에 중요한
          변경이 생기면 적용 전에 앱 또는 공개 정책 페이지를 통해
          안내합니다.
        </p>
        <p>
          최종 약관에는 운영자 정보, 시행일과 법률상 필요한 책임·분쟁 처리
          조항을 확정해 추가합니다.
        </p>
      </section>
    </DocumentShell>
  );
}
