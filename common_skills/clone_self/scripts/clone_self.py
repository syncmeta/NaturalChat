import logging

logger = logging.getLogger(__name__)

async def execute(username: str = "") -> str:
    return (
        "Cloning capability has been switched to the governance approval flow. "
        "Please have the contact send /clone directly or have the creator/admin initiate the clone. "
        f"{'Suggested username: ' + username if username else ''}"
    )
