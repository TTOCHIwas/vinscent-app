import type {
  LearningModelUsage,
} from './learning-model-port.ts';

export interface StructuredGenerationRequest {
  prompt: string;
  schema: Record<string, unknown>;
}

export interface StructuredGenerationResult {
  value: unknown;
  usage: LearningModelUsage;
}

export interface StructuredGenerationClient {
  generateStructured(
    request: StructuredGenerationRequest,
  ): Promise<StructuredGenerationResult>;
}
