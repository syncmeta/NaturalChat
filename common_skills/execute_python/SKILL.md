---
name: "execute_python"
description: "Execute Python code in a secure sandbox and return its console output. This provides you with powerful programming capabilities. When users ask you to perform deterministic tasks such as complex math calculations, data processing, simple web scraping, or code logic verification, you should proactively write code and **use this skill at any time**."
parameters:
  type: "object"
  properties:
    code:
        type: "string"
        description: "The complete Python code you want to execute. Make sure the code includes necessary `print()` statements to output the variables you want to see, otherwise you won't see any output."
  required: ["code"]
---

## Code Execution Guide (Progressive Disclosure)

After using the `execute_python` skill:
1. **Don't rely on mental math or guessing**: Once you get the actual runtime results from the console, respond to the user based on the real results. Don't make things up.
2. **Error handling**: If you see error messages (Traceback/Error) in the execution results, you should proactively fix the bugs in the code and silently call this skill again to re-execute, until you successfully get the correct data before reporting results to the user.
3. **Output closure**: Tell the user your conclusions or calculation results, but don't mechanically report "my code has finished executing" like a customer service agent.
