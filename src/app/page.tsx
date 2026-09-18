export default function HomePage() {
  return (
    <section className="foundation" aria-labelledby="foundation-title">
      <p className="foundation__eyebrow">Phase 1</p>
      <h1 id="foundation-title">A dependable foundation for the TNP portal.</h1>
      <p className="foundation__summary">
        The repository, quality gates, responsive shell, and accessibility baseline are in place.
        Product workflows will be introduced only in their approved phases.
      </p>
      <div className="foundation__rule" aria-hidden="true" />
      <p className="foundation__note">
        This is a development-visible foundation, not a student, recruiter, or administrative
        dashboard.
      </p>
    </section>
  );
}
