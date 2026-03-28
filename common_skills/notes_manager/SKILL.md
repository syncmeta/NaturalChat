---
name: "notes_manager"
description: "Your dedicated backend knowledge base / notebook. When a user assigns you long-term tasks, important specific details (such as addresses, contact information, multi-step plans, etc.), or asks you to remember something specific, proactively call this skill to write down notes. If a user asks about specific facts or plans you memorized earlier, you should use `read` to recall them."
parameters:
  type: "object"
  properties:
    action:
        type: "string"
        enum: ["read", "write", "list", "delete"]
        description: "Action: list (list all note titles), read (read a specific note), write (write or overwrite a note), delete (delete a note)"
    title:
        type: "string"
        description: "A short title for the note (preferably all English with underscores, used as a unique identifier). Used for read, write, and delete actions."
    content:
        type: "string"
        description: "The detailed note content to write (only needed for the write action). If left empty, it is equivalent to deleting/clearing the note."
  required: ["action"]
---

## Notes Management Guide (Progressive Disclosure)

After using the `notes_manager` skill:
1. **Don't be verbose**: If writing a note succeeds, simply say "I've noted that down" in your reply. Don't read back the note content to the user (unless they ask you to).
2. **Knowledge extraction**: When you retrieve something you had forgotten from notes, integrate it into your thinking and reply to the user. Don't robotically say "I read from the file that xxx" -- that doesn't feel natural.
3. **Global isolation**: All notes are a shared knowledge base across users and chats, so when recording a specific user's private information, be sure to include their name or JID in both the `title` and `content` to avoid confusion.
