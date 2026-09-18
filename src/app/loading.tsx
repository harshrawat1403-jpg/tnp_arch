export default function Loading() {
  return (
    <section className="foundation" aria-busy="true" aria-live="polite">
      <p className="foundation__eyebrow">Loading</p>
      <div className="loading-line loading-line--title" />
      <div className="loading-line loading-line--body" />
      <span className="sr-only">Loading page content.</span>
    </section>
  );
}
