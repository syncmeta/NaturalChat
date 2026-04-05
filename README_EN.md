# NaturalChat

> **This project has been discontinued.** Development continues at [BeyondBubble](https://github.com/syncmeta/BeyondBubble).
>
> The Python codebase accumulated too much technical debt — it started as XMPP-centric, then the core logic went through multiple rewrites while staying in the same files. `bot_brain.py` grew to 1800+ lines. A TypeScript rewrite was attempted (the `src/` directory in this repo), completing 8 modules with 154 passing tests, but the architecture wasn't heading in the right direction: the memory system was supposed to use Honcho but ended up as JSON-file storage; the skill system could parse but was never wired into the conversation flow; the Brain was becoming the same monolith as the old code. Starting fresh.

[中文](README.md)

It's for:

- Naturally, proactively chat — like chatting on WhatsApp. It keeps you in mind.
- Break the filter bubble. Surf the internet on its own, from the user's perspective, finding what they actually need.

It has agency. It doesn't just wait for you to ask.

It can be raised by one person, or together with friends.

I have no interest in building another assistant or tool — plenty of those exist. Not trying to build standard AI companionship either — it's not about loneliness or boredom.

I want it to help people live better: solid advice, pointing out blind spots, surfacing valuable information, better plans for life. That's extremely hard — even humans struggle with it. But finding a friend like that might be even harder than building an AI like that. So I'm giving it a shot.

## License

MIT
