/// Evaluates a phase deadline against the shared authoritative server clock.
({Duration remaining, bool expired}) partyPollDeadline({
  required DateTime? phaseEndsAt,
  required DateTime serverNow,
}) {
  if (phaseEndsAt == null) return (remaining: Duration.zero, expired: false);
  final remaining = phaseEndsAt.difference(serverNow);
  return (
    remaining: remaining.isNegative ? Duration.zero : remaining,
    expired: !serverNow.isBefore(phaseEndsAt),
  );
}
