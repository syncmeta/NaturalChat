---
name: "web_search"
description: "Search the web for information and return the latest search result summaries. When users ask about topics requiring the latest information, current events, or facts you're unsure about, you should proactively use this skill to obtain verified data from the web."
parameters:
  type: "object"
  properties:
    query:
        type: "string"
        description: "Search keywords, expressed as phrases most likely to hit search engine results"
    max_results:
        type: "integer"
        description: "Number of results to return (default 5, max 10)"
  required: ["query"]
---

## Search Results Processing Guide (Progressive Disclosure)

After using `web_search` and obtaining a series of search snippets:
1. **Extract the essentials**: Carefully read the search results and extract the one or two key facts you need most. Don't paste or list large blocks of raw search snippets directly to the user.
2. **Cross-validate**: If there is contradictory information in the search results, you should point it out and help the user analyze which source is more credible in your reply.
3. **Stay invisible**: Don't verbosely say "I searched the web and found the following content for you," and don't attach links every time (unless the user specifically asks for them). Like a truly knowledgeable and well-informed friend, directly share the high-value conclusions in a natural, conversational tone.
