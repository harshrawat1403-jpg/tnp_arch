import Link from "next/link";

export default function NotFound() {
  return (
    <section className="foundation" aria-labelledby="not-found-title">
      <p className="foundation__eyebrow">404</p>
      <h1 id="not-found-title">This page is not available.</h1>
      <p className="foundation__summary">Check the address or return to the portal foundation.</p>
      <Link className="text-link" href="/">
        Return home
      </Link>
    </section>
  );
}
