import asyncio
import slixmpp

class TestClient(slixmpp.ClientXMPP):
    def __init__(self, jid, password):
        super().__init__(jid, password)
        self.add_event_handler("session_start", self.start)
        self.add_event_handler("message", self.message)

    async def start(self, event):
        self.send_presence()
        self.get_roster()
        
        # 1. Test clone self
        self.send_message(mto="bot1@chat", mbody="我需要另外一个你，帮我新建一个你的克隆体吧！", mtype='chat')
        
        # Wait up to 60 seconds for a response
        for _ in range(60):
            await asyncio.sleep(1)

    def message(self, msg):
        if msg['type'] in ('chat', 'normal'):
            print(f"Received msg from {msg['from'].bare}: {msg['body']}")
            if "复制成功" in msg['body'] or "bot" in msg['body']:
                print("SUCCESS/PARTIAL: Bot cloning logic triggered!")
                self.disconnect()

if __name__ == '__main__':
    xmpp = TestClient('testuser@chat', 'testpass')
    xmpp.connect(disable_starttls=True, use_ssl=False)
    xmpp.process(forever=False)
