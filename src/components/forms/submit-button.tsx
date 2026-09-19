"use client";

import { useFormStatus } from "react-dom";

type SubmitButtonProps = {
  children: string;
  pendingChildren?: string;
};

export function SubmitButton({ children, pendingChildren = "Saving…" }: SubmitButtonProps) {
  const { pending } = useFormStatus();

  return (
    <button className="button" disabled={pending} type="submit">
      {pending ? pendingChildren : children}
    </button>
  );
}
