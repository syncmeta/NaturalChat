---
name: "ask_friend"
description: "When chatting with someone and you encounter a question that another friend might know the answer to, or when you want to proactively discuss or share something with a specific friend, forcefully and proactively use this skill to send a cross-channel XMPP message to them. If you don't know the friend's JID, you must first check your full friends impressions (friends_impressions) to determine the right person."
parameters:
  type: "object"
  properties:
    target_jid:
        type: "string"
        description: "The target friend's JID, e.g., friend@example.com. This is a required explicit identity."
    message:
        type: "string"
        description: "The text message content you want to send to the target friend."
  required: ["target_jid", "message"]
---

## Cross-Friend Communication Guide (Progressive Disclosure)

After you successfully use the `ask_friend` skill to send a message to another friend, strictly follow these rules:
1. **Don't pretend**: Directly tell the current user in your reply: "I've asked XXX for you, waiting for their reply."
2. **Async waiting**: Your message has already been sent. Please patiently wait for that friend to reply to you in another chat interface. Don't fabricate that person's answer in the current chat.
3. **Close the loop**: When that person replies to you, you will see their reply in your recent chat history. After getting the answer, you should proactively come back and tell the user who originally asked you the question.
