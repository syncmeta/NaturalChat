import os
import json
import httpx


async def execute(namespace: str) -> str:
    namespace = namespace.strip().strip("/")
    rsshub_server = os.environ.get("RSSHUB_SERVER", "http://localhost").rstrip("/")
    url = f"{rsshub_server}/api/routes/{namespace}"

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url)

        if resp.status_code == 204:
            return f"No routes found under namespace '{namespace}' in RSSHub."

        resp.raise_for_status()
        data = resp.json()

        routes = []
        ns_data = data.get("data", {})
        for ns_routes in ns_data.values():
            routes.extend(ns_routes.get("routes", []))

        if not routes:
            return f"No routes found under namespace '{namespace}' in RSSHub."

        route_list = "\n".join(routes)
        return f"Found {len(routes)} actual routes under '{namespace}':\n{route_list}"

    except httpx.HTTPStatusError as e:
        return f"Query failed (HTTP {e.response.status_code}): {e}"
    except Exception as e:
        return f"Query failed: {e}"
