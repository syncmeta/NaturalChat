/**
 * 内嵌 Web Panel HTML — 极简聊天测试页面
 */
export const PANEL_HTML = `<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NaturalChat Web Panel</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f5f5f5; height: 100vh; display: flex; flex-direction: column; }
#header { background: #fff; padding: 12px 16px; border-bottom: 1px solid #e0e0e0; font-size: 16px; font-weight: 600; }
#messages { flex: 1; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 8px; }
.msg { max-width: 70%; padding: 8px 12px; border-radius: 12px; font-size: 14px; line-height: 1.5; word-break: break-word; }
.msg.user { align-self: flex-end; background: #0084ff; color: white; border-bottom-right-radius: 4px; }
.msg.bot { align-self: flex-start; background: white; color: #333; border-bottom-left-radius: 4px; box-shadow: 0 1px 2px rgba(0,0,0,0.1); }
.msg.system { align-self: center; background: transparent; color: #999; font-size: 12px; }
.typing { align-self: flex-start; color: #999; font-size: 13px; padding: 4px 12px; }
#input-area { background: #fff; border-top: 1px solid #e0e0e0; padding: 12px 16px; display: flex; gap: 8px; }
#input { flex: 1; border: 1px solid #ddd; border-radius: 20px; padding: 8px 16px; font-size: 14px; outline: none; }
#input:focus { border-color: #0084ff; }
#send { background: #0084ff; color: white; border: none; border-radius: 20px; padding: 8px 20px; font-size: 14px; cursor: pointer; }
#send:hover { background: #0073e6; }
#send:disabled { background: #ccc; cursor: not-allowed; }
</style>
</head>
<body>
<div id="header">NaturalChat</div>
<div id="messages"></div>
<div id="input-area">
  <input id="input" placeholder="输入消息..." autocomplete="off" />
  <button id="send">发送</button>
</div>
<script>
const messages = document.getElementById("messages");
const input = document.getElementById("input");
const sendBtn = document.getElementById("send");
let typingEl = null;

const protocol = location.protocol === "https:" ? "wss:" : "ws:";
const ws = new WebSocket(protocol + "//" + location.host + "/ws");

ws.onopen = () => addSystem("已连接");
ws.onclose = () => addSystem("连接断���");

ws.onmessage = (e) => {
  try {
    const data = JSON.parse(e.data);
    if (data.type === "typing") {
      showTyping();
    } else if (data.type === "message") {
      hideTyping();
      addMsg(data.text, "bot");
    }
  } catch {}
};

function send() {
  const text = input.value.trim();
  if (!text) return;
  addMsg(text, "user");
  ws.send(JSON.stringify({ type: "message", text }));
  input.value = "";
}

sendBtn.onclick = send;
input.onkeydown = (e) => { if (e.key === "Enter") send(); };

function addMsg(text, cls) {
  const el = document.createElement("div");
  el.className = "msg " + cls;
  el.textContent = text;
  messages.appendChild(el);
  messages.scrollTop = messages.scrollHeight;
}

function addSystem(text) {
  const el = document.createElement("div");
  el.className = "msg system";
  el.textContent = text;
  messages.appendChild(el);
}

function showTyping() {
  if (typingEl) return;
  typingEl = document.createElement("div");
  typingEl.className = "typing";
  typingEl.textContent = "正在输入...";
  messages.appendChild(typingEl);
  messages.scrollTop = messages.scrollHeight;
}

function hideTyping() {
  if (typingEl) { typingEl.remove(); typingEl = null; }
}
</script>
</body>
</html>`;
