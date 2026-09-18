"use client";

type ErrorPageProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function ErrorPage({ error, reset }: ErrorPageProps) {
  console.error(error);

  return (
    <section className="foundation" aria-labelledby="error-title">
      <p className="foundation__eyebrow">Unexpected error</p>
      <h1 id="error-title">We could not load this page.</h1>
      <p className="foundation__summary">
        Please try again. If the issue continues, contact the Training &amp; Placement Office.
      </p>
      <button className="button" type="button" onClick={reset}>
        Try again
      </button>
    </section>
  );
}
