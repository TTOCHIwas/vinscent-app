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

export function optionalEnv(
  name: string,
  readEnvironment: EnvironmentReader = readDenoEnvironment,
) {
  const value = readEnvironment(name)?.trim();
  return value ? value : undefined;
}

export function optionalPositiveIntegerEnv(
  name: string,
  readEnvironment: EnvironmentReader = readDenoEnvironment,
) {
  const value = optionalEnv(name, readEnvironment);
  if (value === undefined) {
    return undefined;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new RangeError(`${name} must be a positive integer`);
  }
  return parsed;
}
