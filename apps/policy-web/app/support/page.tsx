import type { Metadata } from "next";
import Link from "next/link";
import { DocumentShell } from "../_components/document-shell";
import { PolicyDraftNotice } from "../_components/policy-draft-notice";

export const metadata: Metadata = {
  title: "고객지원",
};

export default function SupportPage() {
  return (
    <DocumentShell
      title="고객지원"
      description="단짠을 이용하며 확인할 수 있는 도움말과 문의 경로를 안내하는 초안입니다."
    >
      <PolicyDraftNotice
        id="support-status"
        detail="고객지원에 사용할 공개 이메일과 운영 응답 기준이 확정된 뒤 실제 문의 경로를 연결합니다."
      />

      <section className="policy-section" aria-labelledby="support-in-app">
        <h2 id="support-in-app">앱에서 바로 확인할 수 있어요</h2>
        <ul>
          <li>설정에서 알림 수신 여부와 커플 연결 상태를 확인할 수 있습니다.</li>
          <li>
            계정 메뉴에서 로그인 계정과 계정 삭제 경로를 확인할 수 있습니다.
          </li>
          <li>
            신고 또는 차단이 필요한 콘텐츠는 해당 콘텐츠의 더보기 메뉴에서
            처리할 수 있습니다.
          </li>
        </ul>
      </section>

      <section className="policy-section" aria-labelledby="support-contact">
        <h2 id="support-contact">문의가 필요한 문제</h2>
        <p>
          로그인, 커플 연결, 기록 동기화, 알림, 위젯, AI 결과 또는 안전
          신고와 관련해 앱 안에서 해결되지 않는 문제는 고객지원 문의가
          필요합니다.
        </p>
        <p>
          공개 이메일이 아직 확정되지 않아 현재 이 페이지에서는 문의를
          접수하지 않습니다. 실제 문의 경로가 연결되기 전에는 이 문서를
          공개 배포하지 않습니다.
        </p>
      </section>

      <section className="policy-section" aria-labelledby="support-deletion">
        <h2 id="support-deletion">계정과 데이터 삭제</h2>
        <p>
          앱을 사용할 수 있다면 설정의 계정 메뉴에서 계정과 관련 공유
          데이터를 직접 삭제할 수 있습니다. 앱을 사용할 수 없는 경우의
          절차와 처리 범위는 계정 삭제 안내에서 확인할 수 있습니다.
        </p>
        <p>
          <Link href="/account-deletion">계정 삭제 안내 보기</Link>
        </p>
      </section>
    </DocumentShell>
  );
}
