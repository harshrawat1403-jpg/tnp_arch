type DepartmentIdentityProps = {
  compact?: boolean;
};

export function DepartmentIdentity({ compact = false }: DepartmentIdentityProps) {
  return (
    <span className="department-identity" aria-label="Training and Placement Office">
      <span className="department-identity__mark" aria-hidden="true">
        TNP
      </span>
      {!compact ? (
        <span className="department-identity__copy">
          <span className="department-identity__eyebrow">Department Office</span>
          <span className="department-identity__name">Training &amp; Placement</span>
        </span>
      ) : null}
    </span>
  );
}
