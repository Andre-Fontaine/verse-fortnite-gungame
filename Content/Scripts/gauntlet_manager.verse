using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /Verse.org/Verse }

gauntlet_manager := class(creative_device):

    # ==========================================
    # UEFN EDITABLE PROPERTIES
    # ==========================================

    @editable
    LobbyRequiredPlayers : int = 10

    # Below this many active players, kills stop counting and the Final Showdown starts.
    @editable
    MinPlayersForRooms : int = 5

    # When true, the round never ends just because only one player is left.
    @editable
    SoloTestMode : logic = false

    @editable
    RoomKillRequirements : []int = array{5, 3, 2, 1, 1}

    MaxRooms : int = 5

    # --- LOBBY DEVICES ---
    @editable
    LobbyTeleporter : teleporter_device = teleporter_device{}

    @editable
    LobbyHUD : hud_message_device = hud_message_device{}

    # --- ROOM DEVICES ---
    @editable
    RoomTeleporters : []teleporter_device = array{}

    @editable
    RoomHUDMessages : []hud_message_device = array{}

    @editable
    QualificationHUD : hud_message_device = hud_message_device{}

    # --- RANDOMIZED WEAPON POOLS ---
    @editable
    Room1GranterPool : []item_granter_device = array{}

    @editable
    Room2GranterPool : []item_granter_device = array{}

    @editable
    Room3GranterPool : []item_granter_device = array{}

    @editable
    Room4GranterPool : []item_granter_device = array{}

    @editable
    Room5GranterPool : []item_granter_device = array{}

    # --- GUARD SPAWNERS (one list per room) ---
    @editable
    Room1Spawners : []guard_spawner_device = array{}

    @editable
    Room2Spawners : []guard_spawner_device = array{}

    @editable
    Room3Spawners : []guard_spawner_device = array{}

    @editable
    Room4Spawners : []guard_spawner_device = array{}

    @editable
    Room5Spawners : []guard_spawner_device = array{}

    # --- UTILITY DEVICES ---
    @editable
    WeaponStripper : item_remover_device = item_remover_device{}

    @editable
    ElimManager : elimination_manager_device = elimination_manager_device{}

    @editable
    SpectatorTeleporter : teleporter_device = teleporter_device{}

    @editable
    SpectatorGranter : item_granter_device = item_granter_device{}

    # ==========================================
    # GAME STATE TRACKING
    # ==========================================

    var PlayerCurrentRoom : [agent]int = map{}
    var PlayerKillsInCurrentRoom : [agent]int = map{}
    var PlayerIsQualified : [agent]logic = map{}
    var QualifiedRoomSurvivors : [int]int = map{}
    var RoomTargetQuota : [int]int = map{}
    var ActiveRoomGranterIndices : [int]int = map{}

    var InLobby : [agent]logic = map{}
    var IsSpectator : [agent]logic = map{}
    var ActiveGamePlayers : [agent]logic = map{}

    var SubscribedPlayers : [agent]logic = map{}

    var LobbyPlayerCount : int = 0
    var LobbySequenceStarted : logic = false
    var RoundInProgress : logic = false
    var IsFinalShowdownActive : logic = false


    # ==========================================
    # LIFECYCLE & LOBBY MANAGEMENT
    # ==========================================

    OnBegin<override>()<suspends> : void =
        Print("Gauntlet Manager OnBegin started.")
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)

        AllSpawners := array{Room1Spawners, Room2Spawners, Room3Spawners, Room4Spawners, Room5Spawners}
        for (RoomSpawners : AllSpawners):
            for (Spawner : RoomSpawners):
                Spawner.EliminatedEvent.Subscribe(OnGuardEliminated)

        SetActiveRoomSpawners(-1)

        for (Agent : GetPlayspace().GetParticipants()):
            InitializePlayerInLobby(Agent)

    OnPlayerAdded(Agent : agent) : void =
        InitializePlayerInLobby(Agent)

    InitializePlayerInLobby(Agent : agent) : void =
        if (IsInLobby(Agent) = true) { return }
        if (IsActiveInGame(Agent) = true) { return }
        if (IsSpectator[Agent] = true) { return }

        if (IsSubscribed(Agent) = false):
            if (FortChar := Agent.GetFortCharacter[]):
                FortChar.EliminatedEvent().Subscribe(OnPlayerEliminated)
                if (set SubscribedPlayers[Agent] = true):
                    Print("Subscribed to player eliminations.")

        if (RoundInProgress = true):
            MakePlayerSpectator(Agent)
            return

        if (set InLobby[Agent] = true, set PlayerCurrentRoom[Agent] = 0, set PlayerKillsInCurrentRoom[Agent] = 0, set PlayerIsQualified[Agent] = false, set ActiveGamePlayers[Agent] = false, set IsSpectator[Agent] = false):
            set LobbyPlayerCount += 1
            UpdateLobbyHUD(Agent)

            LobbyTeleporter.Teleport(Agent)
            spawn{ TeleportAgentToLobby(Agent) }

            Print("Participant registered in lobby. Total: {LobbyPlayerCount}/{LobbyRequiredPlayers}")

            if (LobbyPlayerCount >= LobbyRequiredPlayers and LobbySequenceStarted = false):
                set LobbySequenceStarted = true
                Print("Lobby threshold reached! Starting game round...")

                for (P : GetPlayspace().GetParticipants()):
                    LobbyHUD.Hide(P)

                StartGameRound()

    StartGameRound() : void =
        spawn{ ExecuteStartGameRound() }

    ExecuteStartGameRound()<suspends> : void =
        Print("Executing Start Game Round... Transitioning players to Room 1.")
        set RoundInProgress = true
        set IsFinalShowdownActive = false
        SelectRandomWeaponsForMatch()

        var StartingPlayerCount : int = 0

        if (RoomTeleporters.Length > 0, Room1Teleporter := RoomTeleporters[0]):
            for (Agent : GetPlayspace().GetParticipants()):
                if (IsSpectator[Agent] = false):
                    LobbyHUD.Hide(Agent)

                    if (set InLobby[Agent] = false, set PlayerCurrentRoom[Agent] = 0, set PlayerKillsInCurrentRoom[Agent] = 0, set PlayerIsQualified[Agent] = false, set ActiveGamePlayers[Agent] = true):
                        set StartingPlayerCount += 1
                        WeaponStripper.Remove(Agent)

                        Room1Teleporter.Teleport(Agent)
                        spawn{ TeleportAgentToRoom(Agent, Room1Teleporter, 0) }

        CalculateAndSetRoomQuota(0, StartingPlayerCount)

        Sleep(0.5)
        spawn{ StartRoomCountdown(0) }


    # ==========================================
    # TELEPORTATION & RESPAWN
    # ==========================================

    TeleportAgentToLobby(Agent : agent)<suspends> : void =
        LobbyTransform := LobbyTeleporter.GetTransform()
        loop:
            if (FC := Agent.GetFortCharacter[]):
                if (FC.TeleportTo[LobbyTransform.Translation, LobbyTransform.Rotation]):
                    break
            Sleep(0.2)

    TeleportAgentToRoom(Agent : agent, TargetTeleporter : teleporter_device, RoomIndex : int)<suspends> : void =
        TargetTransform := TargetTeleporter.GetTransform()
        loop:
            if (FC := Agent.GetFortCharacter[]):
                OffsetX := GetRandomFloat(-150.0, 150.0)
                OffsetY := GetRandomFloat(-150.0, 150.0)
                TargetPos := TargetTransform.Translation + vector3{X := OffsetX, Y := OffsetY, Z := 10.0}

                if (FC.TeleportTo[TargetPos, TargetTransform.Rotation]):
                    break
            Sleep(0.2)

    HandlePlayerRespawn(Agent : agent, RoomIndex : int)<suspends> : void =
        # Wait a moment for respawn/death sequence to settle
        Sleep(2.5)

        # Verify player is still active, still in this same room, and hasn't qualified yet
        if (IsActiveInGame(Agent) = true, CurrentRoom := PlayerCurrentRoom[Agent], CurrentRoom = RoomIndex, IsQualified(Agent) = false):
            if (RoomIndex < RoomTeleporters.Length, TargetTeleporter := RoomTeleporters[RoomIndex]):
                WeaponStripper.Remove(Agent)
                TargetTeleporter.Teleport(Agent)
                spawn{ TeleportAgentToRoom(Agent, TargetTeleporter, RoomIndex) }

                Sleep(0.3)
                GrantWeaponForRoom(Agent, RoomIndex)
                Print("Player respawned back in Room {RoomIndex + 1}")

    AdvancePlayerToNextRoomEarly(Agent : agent, CurrentRoomIndex : int) : void =
        NextRoomIndex := CurrentRoomIndex + 1
        if (set PlayerCurrentRoom[Agent] = NextRoomIndex, set PlayerKillsInCurrentRoom[Agent] = 0):
            WeaponStripper.Remove(Agent)

            QualificationHUD.SetText(QualificationBannerText())
            QualificationHUD.Show(Agent)

            if (NextRoomIndex < RoomTeleporters.Length, TargetTeleporter := RoomTeleporters[NextRoomIndex]):
                TargetTeleporter.Teleport(Agent)
                spawn{ TeleportAgentToRoom(Agent, TargetTeleporter, NextRoomIndex) }

                if (NextRoomIndex < RoomHUDMessages.Length, NextHUD := RoomHUDMessages[NextRoomIndex]):
                    if (IsFinalShowdownActive = false):
                        NextHUD.SetText(QualifiedWaitingText())
                        NextHUD.Show(Agent)

    SetActiveRoomSpawners(RoomIndex : int) : void =
        Spawners := array{Room1Spawners, Room2Spawners, Room3Spawners, Room4Spawners, Room5Spawners}
        for (Idx -> RoomSpawners : Spawners):
            for (Spawner : RoomSpawners):
                if (Idx = RoomIndex):
                    Spawner.Enable()
                else:
                    Spawner.Disable()


    # ==========================================
    # PROGRESSION, QUOTAS & COMBAT LOGIC
    # ==========================================

    SelectRandomWeaponsForMatch() : void =
        Pools := array{Room1GranterPool, Room2GranterPool, Room3GranterPool, Room4GranterPool, Room5GranterPool}
        for (RoomIdx -> Pool : Pools):
            if (Pool.Length > 0):
                RandomIndex := GetRandomInt(0, Pool.Length - 1)
                if (set ActiveRoomGranterIndices[RoomIdx] = RandomIndex):
                    Print("Selected Room {RoomIdx + 1} Weapon Index: {RandomIndex}")

    CalculateAndSetRoomQuota(RoomIndex : int, TotalPlayersInRoom : int) : void =
        var Quota : int = 1
        if (CalculatedQuota := Quotient[TotalPlayersInRoom * 3, 4], CalculatedQuota > 0):
            set Quota = CalculatedQuota

        if (set RoomTargetQuota[RoomIndex] = Quota, set QualifiedRoomSurvivors[RoomIndex] = 0):
            Print("Room {RoomIndex + 1} Target Survivor Quota: {Quota} (from {TotalPlayersInRoom} participants)")

    OnPlayerEliminated(Result : elimination_result) : void =
        VictimChar := Result.EliminatedCharacter
        if (VictimAgent := VictimChar.GetAgent[]):
            if (EliminatorChar := Result.EliminatingCharacter?, KillerAgent := EliminatorChar.GetAgent[]):
                if (not (KillerAgent = VictimAgent)):
                    OnPlayerScoredKill(KillerAgent)

            if (IsFinalShowdownActive = true or CheckRemainingActivePlayersCount() < MinPlayersForRooms):
                CheckRoundEndCondition()
            else:
                if (CurrentRoomIndex := PlayerCurrentRoom[VictimAgent]):
                    if (IsActiveInGame(VictimAgent) = true, IsQualified(VictimAgent) = false):
                        spawn{ HandlePlayerRespawn(VictimAgent, CurrentRoomIndex) }
                    CheckRoomWaveCompletion(CurrentRoomIndex)

            CheckRoundEndCondition()

    OnGuardEliminated(Result : device_ai_interaction_result) : void =
        Print("Guard eliminated event fired")
        if (Killer := Result.Source?):
            Print("Guard killer found")
            OnPlayerScoredKill(Killer)
        else:
            Print("Guard eliminated with no killer")

    OnPlayerScoredKill(Killer : agent) : void =
        Print("ScoredKill. Active count: {CheckRemainingActivePlayersCount()}, min players: {MinPlayersForRooms}")
        if (IsActiveInGame(Killer) = false):
            Print("ScoredKill ignored: killer is not active in game")
        if (IsFinalShowdownActive = true):
            Print("ScoredKill ignored: final showdown is active")

        if (IsActiveInGame(Killer) = true):
            if (IsFinalShowdownActive = true or CheckRemainingActivePlayersCount() < MinPlayersForRooms) { return }

            if (CurrentRoom := PlayerCurrentRoom[Killer], IsQualified(Killer) = false):
                CurrentKills := GetPlayerKills(Killer) + 1
                if (set PlayerKillsInCurrentRoom[Killer] = CurrentKills):
                    RequiredKills := GetKillsRequiredForRoom(CurrentRoom)
                    UpdateRoomHUD(Killer, CurrentRoom, CurrentKills)

                    if (CurrentKills >= RequiredKills):
                        MarkPlayerQualified(Killer, CurrentRoom)

    MarkPlayerQualified(Agent : agent, RoomIndex : int) : void =
        var OtherPlayers : []agent = array{}
        for (Participant : GetPlayspace().GetParticipants()):
            if (PlayerRoom := PlayerCurrentRoom[Participant], PlayerRoom = RoomIndex, IsActiveInGame(Participant) = true, not (Participant = Agent)):
                set OtherPlayers += array{Participant}

        TotalOthers := OtherPlayers.Length
        var OthersToQualifyCount : int = 0
        if (CalculatedOthers := Quotient[TotalOthers * 3, 4]):
            set OthersToQualifyCount = CalculatedOthers

        if (set PlayerIsQualified[Agent] = true):
            if (RoomIndex < RoomHUDMessages.Length, OldHUD := RoomHUDMessages[RoomIndex]):
                OldHUD.Hide(Agent)
            AdvancePlayerToNextRoomEarly(Agent, RoomIndex)

        var QualifiedOthersCount : int = 0
        for (Other : OtherPlayers):
            if (QualifiedOthersCount < OthersToQualifyCount):
                if (set PlayerIsQualified[Other] = true):
                    set QualifiedOthersCount += 1
                    AdvancePlayerToNextRoomEarly(Other, RoomIndex)

        CompleteRoomWaveAndTransition(RoomIndex)

    CompleteRoomWaveAndTransition(RoomIndex : int) : void =
        NextRoomIndex := RoomIndex + 1

        if (RoomIndex < RoomHUDMessages.Length, HUD := RoomHUDMessages[RoomIndex]):
            HUD.Hide()

        for (Agent : GetPlayspace().GetParticipants()):
            if (PlayerRoom := PlayerCurrentRoom[Agent], PlayerRoom = RoomIndex, IsActiveInGame(Agent) = true):
                if (IsQualified(Agent) = false):
                    if (set ActiveGamePlayers[Agent] = false):
                        MakePlayerSpectator(Agent)

        var SurvivingCount : int = 0
        for (Agent : GetPlayspace().GetParticipants()):
            if (PlayerRoom := PlayerCurrentRoom[Agent], PlayerRoom = NextRoomIndex, IsActiveInGame(Agent) = true):
                set SurvivingCount += 1

        if (SurvivingCount < MinPlayersForRooms and IsFinalShowdownActive = false):
            set IsFinalShowdownActive = true
            Print("Too few players remaining! Triggering Final Showdown.")
            FinalIndex := RoomTeleporters.Length - 1
            if (FinalIndex >= 0, FinalTeleporter := RoomTeleporters[FinalIndex]):
                for (Agent : GetPlayspace().GetParticipants()):
                    if (IsActiveInGame(Agent) = true):
                        if (set PlayerCurrentRoom[Agent] = FinalIndex):
                            WeaponStripper.Remove(Agent)
                            FinalTeleporter.Teleport(Agent)
                            spawn{ TeleportAgentToRoom(Agent, FinalTeleporter, FinalIndex) }

                spawn{ StartFinalShowdownSequence(FinalIndex) }
        else if (NextRoomIndex >= MaxRooms):
            for (Agent : GetPlayspace().GetParticipants()):
                if (IsActiveInGame(Agent) = true):
                    HandleVictory(Agent)
        else:
            CalculateAndSetRoomQuota(NextRoomIndex, SurvivingCount)
            spawn{ StartRoomCountdown(NextRoomIndex) }

    StartFinalShowdownSequence(FinalIndex : int)<suspends> : void =
        for (I := 0 .. RoomHUDMessages.Length - 1):
            if (HUD := RoomHUDMessages[I]) { HUD.Hide() }

        StartRoomCountdown(FinalIndex)

    MakePlayerSpectator(Agent : agent) : void =
        if (set IsSpectator[Agent] = true):
            WeaponStripper.Remove(Agent)
            SpectatorTeleporter.Teleport(Agent)

            SpecTransform := SpectatorTeleporter.GetTransform()
            if (FC := Agent.GetFortCharacter[], FC.TeleportTo[SpecTransform.Translation, SpecTransform.Rotation]):
                Print("Spectator teleported.")

            SpectatorGranter.GrantItem(Agent)


    # ==========================================
    # UI, HUD & COUNTDOWN MANAGEMENT
    # ==========================================

    StartRoomCountdown(RoomIndex : int)<suspends> : void =
        var TimeRemaining : int = 5
        SetActiveRoomSpawners(RoomIndex)
        loop:
            if (TimeRemaining <= 0 or RoundInProgress = false) { break }

            for (Agent : GetPlayspace().GetParticipants()):
                if (PlayerRoom := PlayerCurrentRoom[Agent], PlayerRoom = RoomIndex, IsActiveInGame(Agent) = true):
                    if (RoomIndex < RoomHUDMessages.Length, HUD := RoomHUDMessages[RoomIndex]):
                        if (IsFinalShowdownActive = true):
                            if (TimeRemaining = 5):
                                HUD.SetText(FinalShowdownText())
                                HUD.Show(Agent)
                        else:
                            HUD.SetText(CountdownText(TimeRemaining))
                            HUD.Show(Agent)

            Sleep(1.0)
            set TimeRemaining -= 1

        if (RoundInProgress = true):
            for (Agent : GetPlayspace().GetParticipants()):
                if (PlayerRoom := PlayerCurrentRoom[Agent], PlayerRoom = RoomIndex, IsActiveInGame(Agent) = true):
                    if (set PlayerIsQualified[Agent] = false):
                        UpdateRoomHUD(Agent, RoomIndex, GetPlayerKills(Agent))
                        GrantWeaponForRoom(Agent, RoomIndex)

    UpdateLobbyHUD(Agent : agent) : void =
        LobbyHUD.SetText(LobbyWaitingText(LobbyPlayerCount, LobbyRequiredPlayers))
        LobbyHUD.Show(Agent)

    UpdateRoomHUD(Agent : agent, RoomIndex : int, Kills : int) : void =
        if (IsFinalShowdownActive = true) { return }

        if (RoomIndex < RoomHUDMessages.Length, HUD := RoomHUDMessages[RoomIndex]):
            if (IsQualified(Agent) = true):
                HUD.SetText(QualifiedWaitingText())
                HUD.Show(Agent)
            else:
                RequiredKills := GetKillsRequiredForRoom(RoomIndex)
                HUD.SetText(RoomStatusText(Kills, RequiredKills))
                HUD.Show(Agent)


    # ==========================================
    # VICTORY & RESET FLOW
    # ==========================================

    CheckRoundEndCondition() : void =
        if (SoloTestMode = true) { return }

        ActiveCount := CheckRemainingActivePlayersCount()
        if (ActiveCount <= 1 and RoundInProgress = true):
            var LastPlayerStanding : ?agent = false
            for (Agent : GetPlayspace().GetParticipants()):
                if (IsActiveInGame(Agent) = true):
                    set LastPlayerStanding = option{Agent}

            if (Winner := LastPlayerStanding?):
                HandleVictory(Winner)
            else:
                ResetMatchToLobby()

    HandleVictory(Winner : agent) : void =
        spawn{ HandleVictorySequence(Winner) }

    HandleVictorySequence(Winner : agent)<suspends> : void =
        Print("WE HAVE A WINNER!")
        for (Agent : GetPlayspace().GetParticipants()):
            if (CurrentRoom := PlayerCurrentRoom[Agent], CurrentRoom < RoomHUDMessages.Length, HUD := RoomHUDMessages[CurrentRoom]):
                HUD.SetText(VictoryText())
                HUD.Show(Agent)

        Sleep(4.0)
        ResetMatchToLobby()

    ResetMatchToLobby() : void =
        Print("Resetting match state and returning to lobby...")
        set RoundInProgress = false
        set IsFinalShowdownActive = false
        set LobbySequenceStarted = false
        set LobbyPlayerCount = 0

        set PlayerCurrentRoom = map{}
        set PlayerKillsInCurrentRoom = map{}
        set PlayerIsQualified = map{}
        set QualifiedRoomSurvivors = map{}
        set RoomTargetQuota = map{}
        set ActiveGamePlayers = map{}
        set ActiveRoomGranterIndices = map{}

        SetActiveRoomSpawners(-1)

        if (RoomHUDMessages.Length > 0):
            for (I := 0 .. RoomHUDMessages.Length - 1):
                if (HUD := RoomHUDMessages[I]) { HUD.Hide() }

        for (Agent : GetPlayspace().GetParticipants()):
            if (set IsSpectator[Agent] = false, set InLobby[Agent] = false):
                WeaponStripper.Remove(Agent)
                InitializePlayerInLobby(Agent)


    # ==========================================
    # HELPER & QUERY METHODS
    # ==========================================

    CheckRoomWaveCompletion(RoomIndex : int) : void =
        if (IsFinalShowdownActive = true or CheckRemainingActivePlayersCount() < MinPlayersForRooms) { return }

        CurrentQualified := GetQualifiedCount(RoomIndex)
        Quota := GetTargetQuota(RoomIndex)
        ActiveInRoom := GetPlayersInRoomCount(RoomIndex)

        if (CurrentQualified >= Quota or (ActiveInRoom > 0 and CurrentQualified >= ActiveInRoom)):
            CompleteRoomWaveAndTransition(RoomIndex)

    CheckRemainingActivePlayersCount()<transacts> : int =
        var ActiveCount : int = 0
        for (Agent : GetPlayspace().GetParticipants()):
            if (IsActiveInGame(Agent) = true):
                set ActiveCount += 1
        return ActiveCount

    GrantWeaponForRoom(Agent : agent, RoomIndex : int) : void =
        Pools := array{Room1GranterPool, Room2GranterPool, Room3GranterPool, Room4GranterPool, Room5GranterPool}
        if (SelectedGranterIndex := ActiveRoomGranterIndices[RoomIndex]):
            if (TargetPool := Pools[RoomIndex], Granter := TargetPool[SelectedGranterIndex]):
                Granter.GrantItem(Agent)

    GetKillsRequiredForRoom(RoomIndex : int) : int =
        if (Req := RoomKillRequirements[RoomIndex]) { return Req }
        return 1

    GetPlayerKills(Agent : agent) : int =
        if (Kills := PlayerKillsInCurrentRoom[Agent]) { return Kills }
        return 0

    GetQualifiedCount(RoomIndex : int) : int =
        if (Count := QualifiedRoomSurvivors[RoomIndex]) { return Count }
        return 0

    GetTargetQuota(RoomIndex : int) : int =
        if (Quota := RoomTargetQuota[RoomIndex]) { return Quota }
        return 1

    GetPlayersInRoomCount(RoomIndex : int) : int =
        var Count : int = 0
        for (Agent : GetPlayspace().GetParticipants()):
            if (PlayerRoom := PlayerCurrentRoom[Agent], PlayerRoom = RoomIndex, IsActiveInGame(Agent) = true):
                set Count += 1
        return Count

    IsInLobby(Agent : agent)<transacts> : logic =
        if (Val := InLobby[Agent]) { return Val }
        return false

    IsActiveInGame(Agent : agent)<transacts> : logic =
        if (Val := ActiveGamePlayers[Agent]) { return Val }
        return false

    IsQualified(Agent : agent)<transacts> : logic =
        if (Val := PlayerIsQualified[Agent]) { return Val }
        return false

    IsSubscribed(Agent : agent)<transacts> : logic =
        if (Val := SubscribedPlayers[Agent]) { return Val }
        return false