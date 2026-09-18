import { DepartmentIdentity } from "../brand/department-identity";

export function SiteHeader() {
  return (
    <header className="site-header">
      <div className="site-header__inner">
        <DepartmentIdentity />
        <p className="site-header__status">Portal foundation</p>
      </div>
    </header>
  );
}
