import "server-only";

import { redirect } from "next/navigation";
import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { DriveContent, DriveStatus } from "./validation";

export type Eligibility = {
  academic_result: "PASS" | "FAIL" | "UNDETERMINED";
  availability: "OPEN" | "DEADLINE_PASSED";
  is_eligible: boolean;
  reason_codes: string[];
  evaluated_at: string;
};
export type DriveRow = {
  id: string;
  company_name: string;
  title: string;
  drive_type: DriveContent["drive_type"];
  location?: string | null;
  application_deadline: string;
  status?: DriveStatus;
  revision?: number;
  last_material_change_notice?: string | null;
  eligibility?: Eligibility;
};
export type DriveDetail = DriveRow &
  DriveContent & {
    status: DriveStatus;
    revision: number;
    last_material_change_at: string | null;
  };

export async function requireDriveStaff(managerOnly = false) {
  const identity = await getCurrentIdentity();
  if (!identity) redirect("/login?next=/tnp/drives");
  const roles = managerOnly
    ? ["SUPER_ADMIN", "TNP_SECRETARY"]
    : ["SUPER_ADMIN", "TNP_SECRETARY", "TNP_COORDINATOR"];
  if (!roles.includes(identity.role)) redirect("/account?error=tnp-drive-access-required");
  return identity;
}

export async function getStaffDrive(id: string): Promise<DriveDetail | null> {
  await requireDriveStaff();
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("staff_drive_detail", { p_drive_id: id });
  if (error) throw new Error("Unable to load the drive.");
  return data as DriveDetail | null;
}

export async function getCompanyOptions(page: number) {
  const supabase = await createServerSupabaseClient();
  const from = (page - 1) * 20;
  const { data, error } = await supabase
    .from("companies")
    .select("id, name")
    .eq("is_archived", false)
    .order("normalized_name")
    .order("id")
    .range(from, from + 20);
  if (error) throw new Error("Unable to load active companies.");
  return data as { id: string; name: string }[];
}
