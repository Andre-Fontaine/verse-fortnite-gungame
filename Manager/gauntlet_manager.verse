using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Simulation }

# Localized Text Templates for HUD & Lobby
LobbyWaitingText<localizes>(Current : int, Required : int) : message = "Waiting for players: {Current} / {Required}"
LobbyCountdownText<localizes>(Seconds : int) : message = "Game starting in: {Seconds}..."
RoomStatusText<localizes>(PlayerCount : int) : message = "Players in Room: {PlayerCount}"
CountdownText<localizes>(Seconds : int) : message = "Round starts in: {Seconds}..."
VictoryText<localizes>() : message = "ROUND OVER! Returning to lobby..."

gauntlet_manager := class(creative_device):

    # --- LOBBY SETTINGS ---
    @editable
    LobbyRequiredPlayers : int = 2

    @editable
    LobbyCountdownSeconds : int = 30

    @editable
    LobbyTeleporter : teleporter_device = teleporter_device{}

    @editable
    LobbyHUD : hud_message_device = hud_message_device{}

    # --- ROOM & GAME DEVICES ---
    @editable
    RoomTeleporters : []teleporter_device = array{}

    @editable
    RoomItemGranters : []item_granter_device = array{}

    @editable
    RoomHUDMessages : []hud_message_device = array{}

    @editable
    WeaponStripper : item_remover_device = item_remover_device{}

    @editable
    ElimManager : elimination_manager_device = elimination_manager_device{}

    # --- SPECTATOR DEVICES ---
    @editable
    SpectatorTeleporter : teleporter_device = teleporter_device{}

    @editable
    SpectatorGranter : item_granter_device = item_granter_device{}

    # --- STATE TRACKING ---
    var PlayerCurrentRoom : [agent]int = map{}
    var PlayersInRoomCount : [int]int = map{}
    var RoomActiveMap : [int]logic = map{}
    
    var InLobby : [agent]logic = map{}
    var IsSpectator : [agent]logic = map{}
    var ActiveGamePlayers : [agent]logic = map{}
    
    var LobbyPlayerCount : int = 0
    var LobbySequenceStarted : logic = false
    var RoundInProgress : logic = false

    OnBegin<override>()<suspends> : void =
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)
        ElimManager.EliminationEvent.Subscribe(OnAnyElimination)

        for (Player : GetPlayspace().GetPlayers()):
            InitializePlayerInLobby(Player)

    OnPlayerAdded(Player : agent) : void =
        InitializePlayerInLobby(Player)

    InitializePlayerInLobby(Player : agent) : void =
        if (RoundInProgress = true):
            # Mid-game joiners go straight to Spectator
            MakePlayerSpectator(Player)
            return

        if (set InLobby[Player] = true):
            set LobbyPlayerCount += 1
            UpdateLobbyHUD(Player)
            
            Print("Player joined lobby. Total: {LobbyPlayerCount}/{LobbyRequiredPlayers}")
            
            if (LobbyPlayerCount >= LobbyRequiredPlayers and LobbySequenceStarted = false):
                set LobbySequenceStarted = true
                spawn{ StartLobbyCountdown() }

    UpdateLobbyHUD(Agent : agent) : void =
        LobbyHUD.SetText(LobbyWaitingText(LobbyPlayerCount, LobbyRequiredPlayers))
        LobbyHUD.Show(Agent)

    StartLobbyCountdown()<suspends> : void =
        Print("Lobby threshold reached! Starting countdown...")
        var TimeRemaining : int = LobbyCountdownSeconds
        
        loop:
            if (TimeRemaining <= 0 or LobbySequenceStarted = false):
                break
            
            for (Player : GetPlayspace().GetPlayers()):
                if (IsInLobby(Player) = true):
                    LobbyHUD.SetText(LobbyCountdownText(TimeRemaining))
                    LobbyHUD.Show(Player)
            
            Sleep(1.0)
            set TimeRemaining -= 1
        
        if (LobbySequenceStarted = true):
            StartGameRound()

    StartGameRound() : void =
        set RoundInProgress = true
        
        # Hide Lobby HUD and prepare all active players
        for (Player : GetPlayspace().GetPlayers()):
            if (IsInLobby(Player) = true):
                LobbyHUD.Hide(Player)
                if (set InLobby[Player] = false, set PlayerCurrentRoom[Player] = 0, set ActiveGamePlayers[Player] = true):
                    WeaponStripper.Remove(Player)
                    LobbyTeleporter.Teleport(Player)
                    RegisterPlayerInRoom(Player, 0)

        # Kick off Room 1 countdown
        spawn{ StartRoomCountdown(0) }

    OnAnyElimination(MaybeAgent : ?agent) : void =
        if (Agent := MaybeAgent?):
            # Check if eliminated agent was active in a room
            if (CurrentRoomIndex := PlayerCurrentRoom[Agent]):
                CurrentCount := GetPlayersInRoomCount(CurrentRoomIndex)
                if (CurrentCount > 0):
                    if (set PlayersInRoomCount[CurrentRoomIndex] = CurrentCount - 1):
                        Print("Updated room player count.")
                
                if (OldHUD := RoomHUDMessages[CurrentRoomIndex]):
                    OldHUD.Hide(Agent)

            # Remove from active map and route to Spectator
            if (set ActiveGamePlayers[Agent] = false):
                MakePlayerSpectator(Agent)

            # Check if only 1 active player remains across the entire match
            CheckRoundEndCondition()

    CheckRoundEndCondition() : void =
        var ActiveCount : int = 0
        var LastPlayerStanding : ?agent = false

        for (Player : GetPlayspace().GetPlayers()):
            if (IsActiveInGame(Player) = true):
                set ActiveCount += 1
                set LastPlayerStanding = option{Player}

        Print("Active players remaining: {ActiveCount}")

        if (ActiveCount <= 1 and RoundInProgress = true):
            if (Winner := LastPlayerStanding?):
                HandleVictory(Winner)
            else:
                ResetMatchToLobby()

    MakePlayerSpectator(Agent : agent) : void =
        if (set IsSpectator[Agent] = true):
            WeaponStripper.Remove(Agent)
            SpectatorTeleporter.Teleport(Agent)
            SpectatorGranter.GrantItem(Agent)
            Print("Player routed to Spectator Room.")

    AdvancePlayerRoom(Agent : agent) : void =
        if (CurrentRoomIndex := PlayerCurrentRoom[Agent]):
            if (OldHUD := RoomHUDMessages[CurrentRoomIndex]):
                OldHUD.Hide(Agent)

            if (CurrentRoomIndex < RoomTeleporters.Length, TargetTeleporter := RoomTeleporters[CurrentRoomIndex]):
                NewRoomIndex := CurrentRoomIndex + 1
                
                if (set PlayerCurrentRoom[Agent] = NewRoomIndex):
                    WeaponStripper.Remove(Agent)
                    TargetTeleporter.Teleport(Agent)
                    RegisterPlayerInRoom(Agent, NewRoomIndex)
                    Print("Player advanced to Room {NewRoomIndex + 1}!")
            else:
                HandleVictory(Agent)

    RegisterPlayerInRoom(Agent : agent, RoomIndex : int) : void =
        CurrentCount := GetPlayersInRoomCount(RoomIndex)
        NewCount := CurrentCount + 1
        
        if (set PlayersInRoomCount[RoomIndex] = NewCount):
            UpdateRoomHUD(Agent, RoomIndex, NewCount)
            
            if (IsRoomActive(RoomIndex) = false):
                spawn{ StartRoomCountdown(RoomIndex) }

    UpdateRoomHUD(Agent : agent, RoomIndex : int, Count : int) : void =
        if (HUD := RoomHUDMessages[RoomIndex]):
            HUD.SetText(RoomStatusText(Count))
            HUD.Show(Agent)

    StartRoomCountdown(RoomIndex : int)<suspends> : void =
        if (set RoomActiveMap[RoomIndex] = true):
            Print("Room {RoomIndex + 1} combat starting!")
            
            var TimeRemaining : int = 5
            loop:
                if (TimeRemaining <= 0 or RoundInProgress = false):
                    break
                
                for (Player : GetPlayspace().GetPlayers()):
                    if (PlayerRoom := PlayerCurrentRoom[Player], PlayerRoom = RoomIndex):
                        if (HUD := RoomHUDMessages[RoomIndex]):
                            HUD.SetText(CountdownText(TimeRemaining))
                            HUD.Show(Player)
                    
                Sleep(1.0)
                set TimeRemaining -= 1
            
            if (RoundInProgress = true):
                for (Player : GetPlayspace().GetPlayers()):
                    if (PlayerRoom := PlayerCurrentRoom[Player], PlayerRoom = RoomIndex):
                        UpdateRoomHUD(Player, RoomIndex, GetPlayersInRoomCount(RoomIndex))

                GrantWeaponsToRoom(RoomIndex)

    GrantWeaponsToRoom(RoomIndex : int) : void =
        for (Player : GetPlayspace().GetPlayers()):
            if (PlayerRoom := PlayerCurrentRoom[Player], PlayerRoom = RoomIndex):
                GrantWeaponForRoom(Player, RoomIndex)

    GrantWeaponForRoom(Agent : agent, RoomIndex : int) : void =
        if (Granter := RoomItemGranters[RoomIndex]):
            Granter.GrantItem(Agent)

    GetPlayersInRoomCount(RoomIndex : int) : int =
        if (Val := PlayersInRoomCount[RoomIndex]):
            return Val
        return 0

    IsInLobby(Player : agent)<transacts> : logic =
        if (Val := InLobby[Player]):
            return Val
        return false

    IsSpectatorPlayer(Player : agent)<transacts> : logic =
        if (Val := IsSpectator[Player]):
            return Val
        return false

    IsActiveInGame(Player : agent)<transacts> : logic =
        if (Val := ActiveGamePlayers[Player]):
            return Val
        return false

    IsRoomActive(RoomIndex : int)<transacts> : logic =
        if (Val := RoomActiveMap[RoomIndex]):
            return Val
        return false

    HandleVictory(Winner : agent) : void =
        spawn{ HandleVictorySequence(Winner) }

    HandleVictorySequence(Winner : agent)<suspends> : void =
        Print("WE HAVE A WINNER!")
        
        # Display victory announcement HUD
        for (Player : GetPlayspace().GetPlayers()):
            if (CurrentRoom := PlayerCurrentRoom[Player], HUD := RoomHUDMessages[CurrentRoom]):
                HUD.SetText(VictoryText())
                HUD.Show(Player)

        Sleep(4.0)
        ResetMatchToLobby()

    ResetMatchToLobby() : void =
        Print("Resetting match state and sending everyone back to lobby...")
        
        # Reset overall round state
        set RoundInProgress = false
        set LobbySequenceStarted = false
        set LobbyPlayerCount = 0
        set PlayersInRoomCount = map{}
        set RoomActiveMap = map{}
        set PlayerCurrentRoom = map{}
        set ActiveGamePlayers = map{}

        # Hide active room HUDs
        for (HUD : RoomHUDMessages):
            HUD.Hide()

        # Teleport ALL players back to pre-game lobby and re-register them
        for (Player : GetPlayspace().GetPlayers()):
            if (set IsSpectator[Player] = false):
                Print("Reset spectator status for player.")
            WeaponStripper.Remove(Player)
            
            # Re-initialize player in lobby
            InitializePlayerInLobby(Player)