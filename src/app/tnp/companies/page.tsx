import Link from "next/link";

import { SubmitButton } from "@/components/forms/submit-button";
import { pageItems, pageRange, parsePageParameter } from "@/lib/pagination";
import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { createCompany } from "./actions";

type Company = {
  id: string;
  is_archived: boolean;
  name: string;
  website_url: string | null;
};

type SearchParameters = {
  archived?: string | string[];
  page?: string | string[];
  q?: string | string[];
  state?: string | string[];
};

export const dynamic = "force-dynamic";

function parameter(value: string | string[] | undefined): string {
  return typeof value === "string" ? value : "";
}

function listHref(search: string, archived: boolean, page: number): string {
  const query = new URLSearchParams();
  if (search) query.set("q", search);
  if (archived) query.set("archived", "true");
  if (page > 1) query.set("page", String(page));
  const serialized = query.toString();
  return serialized ? `/tnp/companies?${serialized}` : "/tnp/companies";
}

export default async function CompaniesPage({
  searchParams,
}: {
  searchParams: Promise<SearchParameters>;
}) {
  const identity = await getCurrentIdentity();
  if (!identity || !["SUPER_ADMIN", "TNP_SECRETARY", "TNP_COORDINATOR"].includes(identity.role)) {
    return (
      <section className="student-page">
        <h1>Company records are restricted to TNP staff.</h1>
      </section>
    );
  }

  const parameters = await searchParams;
  const search = parameter(parameters.q).trim().slice(0, 160);
  const archived = parameter(parameters.archived) === "true";
  const page = parsePageParameter(parameters.page);
  const range = pageRange(page);
  const supabase = await createServerSupabaseClient();
  let query = supabase
    .from("companies")
    .select("id, name, website_url, is_archived")
    .eq("is_archived", archived)
    .order("normalized_name", { ascending: true })
    .order("id", { ascending: true })
    .range(range.from, range.to);
  if (search) query = query.ilike("name", `%${search}%`);
  const { data, error } = await query;
  if (error) throw new Error("Unable to load company records.");
  const companies = pageItems(data as Company[]);
  const state = parameter(parameters.state);

  return (
    <section className="student-page" aria-labelledby="companies-title">
      <p className="foundation__eyebrow">TNP administration</p>
      <h1 id="companies-title">Companies and recruiters</h1>
      <p className="student-page__summary">
        A bounded operational register. Company, contact, invitation, and access decisions remain
        enforced by database procedures.
      </p>
      {state === "error" ? (
        <p className="auth-panel__message" role="alert">
          That company operation could not be completed.
        </p>
      ) : null}

      <form action="/tnp/companies" className="profile-form" method="get">
        <fieldset>
          <legend>Find a company</legend>
          <label htmlFor="company-search">Company name</label>
          <input defaultValue={search} id="company-search" maxLength={160} name="q" type="search" />
          <label>
            <input defaultChecked={archived} name="archived" type="checkbox" value="true" /> Show
            archived companies
          </label>
          <button className="button" type="submit">
            Search
          </button>
        </fieldset>
      </form>

      <section className="skills-list" aria-labelledby="company-list-title">
        <h2 id="company-list-title">{archived ? "Archived companies" : "Active companies"}</h2>
        {companies.items.length === 0 ? (
          <p>No matching company records are available.</p>
        ) : (
          companies.items.map((company) => (
            <article className="skill-record" key={company.id}>
              <h3>{company.name}</h3>
              <p>{company.is_archived ? "Archived" : "Active"}</p>
              {company.website_url ? <p>{company.website_url}</p> : null}
              <Link className="text-link" href={`/tnp/companies/${company.id}`}>
                Open record
              </Link>
            </article>
          ))
        )}
        {page > 1 || companies.hasNext ? (
          <nav aria-label="Company pagination" className="pagination">
            {page > 1 ? (
              <Link href={listHref(search, archived, page - 1)}>Previous</Link>
            ) : (
              <span>Previous</span>
            )}
            <span>Page {page}</span>
            {companies.hasNext ? (
              <Link href={listHref(search, archived, page + 1)}>Next</Link>
            ) : (
              <span>Next</span>
            )}
          </nav>
        ) : null}
      </section>

      <section className="skills-list" aria-labelledby="company-create-title">
        <h2 id="company-create-title">Create company record</h2>
        <form action={createCompany} className="profile-form">
          <fieldset>
            <label htmlFor="company-name">Company name</label>
            <input id="company-name" maxLength={160} name="name" required />
            <label htmlFor="company-website">
              Website <span>(HTTPS, optional)</span>
            </label>
            <input id="company-website" name="websiteUrl" placeholder="https://…" type="url" />
            <label htmlFor="company-description">
              Description <span>(optional)</span>
            </label>
            <textarea id="company-description" maxLength={4000} name="description" rows={4} />
            <SubmitButton>Create company</SubmitButton>
          </fieldset>
        </form>
      </section>
    </section>
  );
}
