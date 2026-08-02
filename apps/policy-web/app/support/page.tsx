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
        detail="공개 고객지원 이메일은 연결되어 있습니다. 운영 응답 기준은 확정한 뒤 최종 안내에 반영합니다."
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
          <a href="mailto:vinscent0929@gmail.com?subject=%EB%8B%A8%EC%A7%A0%20%EA%B3%A0%EA%B0%9D%EC%A7%80%EC%9B%90%20%EB%AC%B8%EC%9D%98">
            vinscent0929@gmail.com
          </a>
          으로 문의할 수 있습니다. 문제를 확인할 수 있도록 이용한 기기와
          OS, 발생한 화면과 시각을 함께 적어 주세요. 비밀번호, 인증 코드와
          API 키는 보내지 마세요.
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
