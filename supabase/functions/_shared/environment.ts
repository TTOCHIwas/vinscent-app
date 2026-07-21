export type EnvironmentReader = (name: string) => string | undefined;

export const readDenoEnvironment: EnvironmentReader = (name) =>
  Deno.env.get(name);

export function requiredEnv(
  name: string,
  readEnvironment: EnvironmentReader = readDenoEnvironment,
) {
  const value = readEnvironment(name);
  if (!value) {
    throw new Error(`missing_env:${name}`);
  }

  return value;
}
