import os
import glob

# Use a storage area independent of the memory system as the file notes repository
_NOTES_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "workspace", "notes")
os.makedirs(_NOTES_DIR, exist_ok=True)

async def execute(action: str, title: str = "", content: str = "") -> str:
    if action == "list":
        files = glob.glob(os.path.join(_NOTES_DIR, "*.md"))
        titles = [os.path.basename(f)[:-3] for f in files]
        if not titles:
            return "No notes have been recorded yet."
        return "Current list of known memory notes (use the read action with the corresponding title to get details):\n" + "\n".join(f"- {t}" for t in titles)

    elif action == "read":
        if not title:
            return "Error: A note title (title) is required."
        path = os.path.join(_NOTES_DIR, f"{title}.md")
        if not os.path.exists(path):
            return f"Cannot find a note named '{title}'. Please use list first to view existing notes."
        with open(path, "r", encoding="utf-8") as f:
            return f"Contents of note '{title}':\n{f.read()}"

    elif action == "write":
        if not title:
            return "Error: A note title (title) is required."
        path = os.path.join(_NOTES_DIR, f"{title}.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return f"Memory has been successfully recorded as a note in '{title}.md'."

    elif action == "delete":
        if not title:
            return "Error: A note title (title) is required."
        path = os.path.join(_NOTES_DIR, f"{title}.md")
        if os.path.exists(path):
            os.remove(path)
            return f"Note '{title}' has been deleted."
        else:
            return f"Cannot find a note named '{title}'."

    return f"Unknown action: {action}."
