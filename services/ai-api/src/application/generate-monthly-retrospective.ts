import type { MonthlyGeneratedContent, MonthlyGenerationContext } from './monthly-retrospective-model.ts';

export type MonthlyGenerationClaim = { claimed: false } | (MonthlyGenerationContext & {
  claimed: true; retrospective_id: string; token: string;
});

export interface MonthlyRetrospectiveGateway {
  prepare(userId: string): Promise<MonthlyGenerationClaim>;
  finish(id: string, token: string, content: MonthlyGeneratedContent | null): Promise<boolean>;
}

export class GenerateMonthlyRetrospective {
  readonly #gateway: MonthlyRetrospectiveGateway;
  readonly #model: () => { generate(context: MonthlyGenerationContext): Promise<MonthlyGeneratedContent> };

  constructor(options: { gateway: MonthlyRetrospectiveGateway; model: () => { generate(context: MonthlyGenerationContext): Promise<MonthlyGeneratedContent> } }) {
    this.#gateway = options.gateway;
    this.#model = options.model;
  }

  async execute(userId: string): Promise<boolean> {
    const claim = await this.#gateway.prepare(userId);
    if (!claim.claimed) return false;
    try {
      const content = await this.#model().generate({month:claim.month,questions:claim.questions});
      return await this.#gateway.finish(claim.retrospective_id, claim.token, content);
    } catch (error) {
      try {
        await this.#gateway.finish(claim.retrospective_id, claim.token, null);
      } catch {
        // A failed release remains retryable after the server lease expires.
      }
      throw error;
    }
  }
}
