type PolicyDraftNoticeProps = {
  id: string;
  detail: string;
};

export function PolicyDraftNotice({ id, detail }: PolicyDraftNoticeProps) {
  return (
    <section className="publication-notice" aria-labelledby={id}>
      <h2 id={id}>공개 전 검토 중입니다</h2>
      <p>{detail}</p>
      <p>
        법적 운영자명, 공개 문의처, 시행일, 이용 연령과 일부 보관 기간이
        확정되기 전까지 이 문서는 배포용 최종본이 아닙니다.
      </p>
    </section>
  );
}
