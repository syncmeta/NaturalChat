---
name: "rsshub_search"
description: "Query actually existing routes on RSSHub. Before deciding to subscribe to a source (e.g., v2ex, zhihu, bilibili), you must first call this tool to confirm the route actually exists. Do not guess paths. Returns a list of all available actual routes under the given namespace."
parameters:
  type: "object"
  properties:
    namespace:
      type: "string"
      description: "The source namespace to query, i.e., the first segment of the route path, such as 'v2ex', 'zhihu', 'bilibili', '36kr', 'weibo', etc."
  required: ["namespace"]
---

## Usage Guide

After calling this tool, you will get a list of all actually existing route paths under the given namespace.

Select the appropriate route from the returned list to add to rsshub_routes. **Do not use paths outside the list**.
If the result is empty, it means RSSHub does not support that source. Try a different one.
