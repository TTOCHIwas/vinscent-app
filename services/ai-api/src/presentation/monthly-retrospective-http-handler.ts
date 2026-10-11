export function createMonthlyRetrospectiveHttpHandler(options: {
  authenticator: { authenticate(token: string): Promise<string | null> };
  generator: { execute(userId: string): Promise<boolean> };
}): (request: Request) => Promise<Response> {
  return async (request) => {
    if (request.method !== 'POST') return json(405, {error:'method_not_allowed'});
    const token = /^Bearer\s+(\S+)$/i.exec(request.headers.get('authorization') ?? '')?.[1];
    if (!token) return json(401, {error:'unauthorized'});
    let userId: string | null;
    try { userId = await options.authenticator.authenticate(token); }
    catch { userId = null; }
    if (!userId) return json(401, {error:'unauthorized'});
    try {
      const completed = await options.generator.execute(userId);
      return json(completed ? 200 : 202, {completed});
    } catch {
      return json(503, {error:'monthly_retrospective_unavailable'});
    }
  };
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store'}});
}
