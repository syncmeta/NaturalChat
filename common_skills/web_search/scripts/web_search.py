import os
import json
import asyncio

async def _search_serper(query: str, max_results: int, api_key: str) -> str:
    import httpx
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            "https://google.serper.dev/search",
            headers={"X-API-KEY": api_key, "Content-Type": "application/json"},
            json={"q": query, "num": max_results, "hl": "zh-cn"},
        )
        resp.raise_for_status()
        data = resp.json()

    results = []
    for item in data.get("organic", [])[:max_results]:
        title = item.get("title", "")
        snippet = item.get("snippet", "")
        link = item.get("link", "")
        results.append(f"[{title}]\n{snippet}\n{link}")

    if data.get("answerBox"):
        ab = data["answerBox"]
        answer = ab.get("answer") or ab.get("snippet", "")
        if answer:
            results.insert(0, f"[Direct Answer] {answer}")

    return "\n\n".join(results) if results else "No relevant results found."

async def _search_ddg(query: str, max_results: int) -> str:
    try:
        from ddgs import DDGS
    except ImportError:
        from duckduckgo_search import DDGS

    def _sync_search():
        with DDGS() as ddgs:
            return list(ddgs.text(query, max_results=max_results, region="wt-wt"))

    results_raw = await asyncio.get_event_loop().run_in_executor(None, _sync_search)

    if not results_raw:
        return "No relevant results found."

    results = []
    for r in results_raw:
        title = r.get("title", "")
        body = r.get("body", "")
        href = r.get("href", "")
        results.append(f"[{title}]\n{body}\n{href}")

    return "\n\n".join(results)

async def execute(query: str, max_results: int = 5) -> str:
    max_results = min(max(1, max_results), 10)
    serper_key = os.environ.get("SERPER_API_KEY", "")

    try:
        if serper_key:
            return await _search_serper(query, max_results, serper_key)
        else:
            return await _search_ddg(query, max_results)
    except Exception as e:
        if serper_key:
            try:
                return await _search_ddg(query, max_results)
            except Exception:
                pass
        return f"Search failed: {e}"
