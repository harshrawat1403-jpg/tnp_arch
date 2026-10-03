// Display labels only, never an independent eligibility calculation.
export const REASON_LABELS: Record<string, string> = {
  ELIGIBLE: "You meet the current criteria.",
  COURSE_NOT_ELIGIBLE: "Your protected roster course is not eligible.",
  BATCH_NOT_ELIGIBLE: "Your course/batch pair is not eligible.",
  CGPA_BELOW_MINIMUM: "Your verified CGPA is below the minimum.",
  ACTIVE_BACKLOG_LIMIT_EXCEEDED: "Your verified active backlogs exceed the limit.",
  PREVIOUSLY_SELECTED_PLACEMENT: "A current prior placement selection is excluded by this drive.",
  ACADEMIC_DATA_UNAVAILABLE:
    "Academic information is unavailable; eligibility cannot yet be determined.",
  ACADEMIC_UNVERIFIED: "Your academics need verification before eligibility can be determined.",
  DEADLINE_PASSED: "The application deadline has passed.",
  DRIVE_CRITERIA_UNAVAILABLE:
    "Drive criteria are unavailable; eligibility cannot yet be determined.",
};

export function deadlineLabel(value: string): string {
  return (
    new Intl.DateTimeFormat("en-IN", {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone: "Asia/Kolkata",
    }).format(new Date(value)) + " IST"
  );
}
