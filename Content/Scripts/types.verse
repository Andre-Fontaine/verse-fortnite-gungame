using { /Verse.org/Verse }

# --- LOCALIZED MESSAGES ---
LobbyWaitingText<localizes>(Current : int, Required : int) : message = "Waiting for players: {Current} / {Required}"
RoomStatusText<localizes>(Kills : int, Target : int) : message = "Kills: {Kills} / {Target}"
QualifiedWaitingText<localizes>() : message = "QUALIFIED! Waiting for room to finish..."
QualificationBannerText<localizes>() : message = "QUALIFIED! Moving to Next Room!"
FinalShowdownText<localizes>() : message = "FINAL SHOWDOWN! Last person standing wins!"
CountdownText<localizes>(Seconds : int) : message = "Round starts in: {Seconds}..."
VictoryText<localizes>() : message = "MATCH OVER! Returning to lobby..."