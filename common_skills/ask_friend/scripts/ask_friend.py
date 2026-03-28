import logging

logger = logging.getLogger(__name__)

async def execute(target_jid: str, message: str) -> str:
    from src.bot_manager import global_bot_manager
    if not global_bot_manager:
        return "Execution failed: Unable to access the global BotManager."

    try:
        success = await global_bot_manager.send_message_as_bot(target_jid, message)

        if success:
            return f"Successfully sent a message to {target_jid}: '{message}'"
        else:
            return f"Send failed: Could not find a valid bot client or not connected."

    except Exception as e:
        logger.error(f"Ask friend failed: {e}")
        return f"Failed to send question/share to friend: {str(e)}"
