type PublicEnvironmentInput = {
  appUrl?: string | undefined;
  nodeEnv?: string | undefined;
};

export type PublicEnvironment = {
  appUrl?: URL;
  nodeEnv: "development" | "test" | "production";
};

const supportedNodeEnvironments = new Set<PublicEnvironment["nodeEnv"]>([
  "development",
  "test",
  "production",
]);

export function validatePublicEnvironment(input: PublicEnvironmentInput): PublicEnvironment {
  const nodeEnv = input.nodeEnv ?? "development";

  if (!supportedNodeEnvironments.has(nodeEnv as PublicEnvironment["nodeEnv"])) {
    throw new Error("NODE_ENV must be development, test, or production.");
  }

  if (!input.appUrl) {
    return { nodeEnv: nodeEnv as PublicEnvironment["nodeEnv"] };
  }

  let appUrl: URL;

  try {
    appUrl = new URL(input.appUrl);
  } catch {
    throw new Error("NEXT_PUBLIC_APP_URL must be an absolute HTTP(S) URL.");
  }

  if (appUrl.protocol !== "http:" && appUrl.protocol !== "https:") {
    throw new Error("NEXT_PUBLIC_APP_URL must use HTTP or HTTPS.");
  }

  return { appUrl, nodeEnv: nodeEnv as PublicEnvironment["nodeEnv"] };
}

export function getPublicEnvironment(): PublicEnvironment {
  return validatePublicEnvironment({
    appUrl: process.env.NEXT_PUBLIC_APP_URL,
    nodeEnv: process.env.NODE_ENV,
  });
}
