export type SupabaseEnvironmentInput = {
  publishableKey?: string | undefined;
  url?: string | undefined;
};

export type SupabaseEnvironment = {
  publishableKey: string;
  url: URL;
};

function getRequiredValue(value: string | undefined, variableName: string): string {
  const trimmedValue = value?.trim();

  if (!trimmedValue) {
    throw new Error(`${variableName} must be set to use Supabase Auth.`);
  }

  return trimmedValue;
}

export function validateSupabaseEnvironment(input: SupabaseEnvironmentInput): SupabaseEnvironment {
  const urlValue = getRequiredValue(input.url, "NEXT_PUBLIC_SUPABASE_URL");
  const publishableKey = getRequiredValue(
    input.publishableKey,
    "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
  );

  let url: URL;

  try {
    url = new URL(urlValue);
  } catch {
    throw new Error("NEXT_PUBLIC_SUPABASE_URL must be an absolute HTTP(S) URL.");
  }

  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error("NEXT_PUBLIC_SUPABASE_URL must use HTTP or HTTPS.");
  }

  return { publishableKey, url };
}

export function getSupabaseEnvironment(): SupabaseEnvironment {
  return validateSupabaseEnvironment({
    url: process.env.NEXT_PUBLIC_SUPABASE_URL,
    publishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  });
}

export function getOptionalSupabaseEnvironment(): SupabaseEnvironment | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url && !publishableKey) {
    return null;
  }

  return validateSupabaseEnvironment({ url, publishableKey });
}
