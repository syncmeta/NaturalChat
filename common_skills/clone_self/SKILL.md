---
name: "clone_self"
description: "Use this skill to clone yourself when you need to create a new bot instance, or when you want to create a new conversational entity for some purpose. This will very quickly generate a copy bot with independent memory within one second."
parameters:
  type: "object"
  properties:
    username:
        type: "string"
        description: "Optional parameter. If the user specifies a name, or you want to give the new bot an interesting name (can include Chinese/English), fill it in here. If left empty, a random name will be automatically generated."
---

## Cloning Guide (Progressive Disclosure)

After executing this skill:
1. The system will immediately generate and start a clone of you in the background.
2. You will receive the full username (JID, e.g., `xxx@chat`) of the newly created bot in the execution result.
3. Please immediately include this new username in your reply to the user, and prompt the user to proactively add this account as a friend in their XMPP client.
