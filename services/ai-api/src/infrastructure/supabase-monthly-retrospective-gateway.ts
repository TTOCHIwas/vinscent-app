import type { MonthlyGenerationClaim, MonthlyRetrospectiveGateway } from '../application/generate-monthly-retrospective.ts';
import type { MonthlyGeneratedContent } from '../application/monthly-retrospective-model.ts';

interface RpcClient {
  rpc(name: string, args: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }>;
}

export class SupabaseMonthlyRetrospectiveGateway implements MonthlyRetrospectiveGateway {
  readonly #client: RpcClient;
  constructor(client: RpcClient) { this.#client = client; }

  async prepare(userId: string): Promise<MonthlyGenerationClaim> {
    const { data, error } = await this.#client.rpc('prepare_monthly_retrospective_generation', {requested_user_id:userId});
    if (error !== null) throw new Error('monthly_context_unavailable');
    if (typeof data !== 'object' || data === null || !('claimed' in data)) throw new TypeError('invalid monthly claim');
    const row = data as Record<string, unknown>;
    if (row.claimed === false) return {claimed:false};
    if (row.claimed !== true || typeof row.retrospective_id !== 'string' || typeof row.token !== 'string'
      || typeof row.month !== 'string' || !Array.isArray(row.questions) || row.questions.length === 0) {
      throw new TypeError('invalid monthly claim');
    }
    const questions = row.questions.map((question: unknown) => {
      if (typeof question !== 'object' || question === null) throw new TypeError('invalid monthly question');
      const q = question as Record<string, unknown>;
      if (typeof q.id !== 'string' || typeof q.text !== 'string' || !Array.isArray(q.answers)
        || q.answers.length !== 2 || q.answers.some((answer) => typeof answer !== 'string')) throw new TypeError('invalid monthly answers');
      return {id:q.id,text:q.text,answers:q.answers as string[]};
    });
    return {claimed:true,retrospective_id:row.retrospective_id,token:row.token,month:row.month,questions};
  }

  async finish(id: string, token: string, content: MonthlyGeneratedContent | null): Promise<boolean> {
    const { data, error } = await this.#client.rpc('finish_monthly_retrospective_generation', {
      requested_retrospective_id:id,requested_token:token,requested_content:content,
    });
    if (error !== null) throw new Error('monthly_completion_unavailable');
    return data === true;
  }
}
