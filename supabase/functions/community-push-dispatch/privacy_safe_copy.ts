// Static event-state copy only. Never interpolate a name, message, health value,
// reward amount, or sender-provided preview/locale into a hidden preview.
const communityStates = new Map<string, string>([
  ["friend_accepted_v1", "Your friend request was accepted."],
  ["post_approved_ai_tokens_v1", "Your post was approved."],
  ["post_approved_no_ai_tokens_v1", "Your post was approved."],
  ["post_rejected_v1", "Your post needs changes."],
  ["community_post_ai_reward_v1", "You received an AI token reward."],
]);

export function privacySafePushBody(
  category: unknown,
  copyKey: unknown,
): string {
  switch (category) {
    case "message":
      return "You have a new message.";
    case "friend_request":
      return "You have a new friend request.";
    case "ai_coach":
      return "Your coach has an update.";
    case "community":
      return (typeof copyKey === "string"
        ? communityStates.get(copyKey)
        : null) ??
        "There is an update in your community.";
    default:
      return "You have a new update.";
  }
}
