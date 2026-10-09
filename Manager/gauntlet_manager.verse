using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Simulation }

gauntlet_manager := class(creative_device):

    @editable
    TestButton : button_device = button_device{}

    @editable
    RoomTeleporters : []teleporter_device = array{}

    @editable
    RoomItemGranters : []item_granter_device = array{}

    @editable
    WeaponStripper : item_remover_device = item_remover_device{}

    @editable
    RoomGuardSpawners : []guard_spawner_device = array{}

    # Lets you track Guard/NPC kills
    @editable
    ElimManager : elimination_manager_device = elimination_manager_device{}

    # Bypasses the "Wait for Everyone" lock so you can test alone
    @editable
    SoloTestMode : logic = false

    var PlayerCurrentRoom : [agent]int = map{}
    var PlayersInRoomCount : [int]int = map{}
    var RoomActiveMap : [int]logic = map{}

    OnBegin<override>()<suspends> : void =
        TestButton.InteractedWithEvent.Subscribe(OnTestButtonPressed)
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)
        
        # Subscribes to ANY elimination on the map (Players or Guards)
        ElimManager.EliminationEvent.Subscribe(OnAnyElimination)

        for (Player : GetPlayspace().GetPlayers()):
            InitializePlayer(Player)

    OnPlayerAdded(Player : agent) : void =
        InitializePlayer(Player)

    InitializePlayer(Player : agent) : void =
        if (set PlayerCurrentRoom[Player] = 0):
            RegisterPlayerInRoom(Player, 0)

    OnTestButtonPressed(Agent : agent) : void =
        AdvancePlayerRoom(Agent)

    # Replaces MonitorPlayerEliminations and accepts ?agent from Elimination Manager
    OnAnyElimination(MaybeAgent : ?agent) : void =
        if (Agent := MaybeAgent?):
            AdvancePlayerRoom(Agent)

    AdvancePlayerRoom(Agent : agent) : void =
        if (CurrentRoomIndex := PlayerCurrentRoom[Agent]):
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
            
            # Determine how many players we are waiting for
            var RequiredPlayers : int = GetPlayspace().GetPlayers().Length
            
            # Override if testing solo
            if (SoloTestMode = true):
                set RequiredPlayers = 1
            
            if (NewCount >= RequiredPlayers):
                if (IsRoomActive(RoomIndex) = false):
                    spawn{ StartRoomCountdown(RoomIndex) }

    StartRoomCountdown(RoomIndex : int)<suspends> : void =
        if (set RoomActiveMap[RoomIndex] = true):
            Print("All players present in Room {RoomIndex + 1}!")
            
            var TimeRemaining : int = 5
            loop:
                if (TimeRemaining <= 0):
                    break
                Print("Round starts in: {TimeRemaining}...")
                Sleep(1.0)
                set TimeRemaining -= 1
            
            Print("FIGHT!")
            GrantWeaponsToRoom(RoomIndex)
            
            # Enable device, wait 1 tick for initialization, then spawn
            if (Spawner := RoomGuardSpawners[RoomIndex]):
                Spawner.Enable()
                Sleep(0.1) # Critical tick delay for engine state update
                Spawner.Spawn()
                Print("Successfully spawned guard for Room {RoomIndex + 1}")
            else:
                Print("ERROR: RoomGuardSpawners[{RoomIndex}] is not assigned in the Details panel!")

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

    IsRoomActive(RoomIndex : int)<transacts> : logic =
        if (Val := RoomActiveMap[RoomIndex]):
            return Val
        return false

    HandleVictory(Agent : agent) : void =
        Print("We have a winner!")