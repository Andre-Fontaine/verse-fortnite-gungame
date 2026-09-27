using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Simulation }

<#
    Gauntlet Manager
    Handles a synchronized, multi-room gun game sequence.
    Features async elimination tracking across respawns, dynamic room advancement, 
    and a stasis-free waiting phase with synchronized weapon distribution.
#>
gauntlet_manager := class(creative_device):

    # -------------------------------------------------------------------------
    # EXTERNAL DEVICES
    # -------------------------------------------------------------------------
    @editable
    TestButton : button_device = button_device{}

    @editable
    RoomTeleporters : []teleporter_device = array{}

    @editable
    RoomItemGranters : []item_granter_device = array{}

    @editable
    WeaponStripper : item_remover_device = item_remover_device{}

    # -------------------------------------------------------------------------
    # INTERNAL STATE
    # -------------------------------------------------------------------------
    # Maps an agent to their current room index (0-based)
    var PlayerCurrentRoom : [agent]int = map{}
    
    # Tracks the number of players waiting in a specific room
    var PlayersInRoomCount : [int]int = map{}

    # Flags if a room's 5-second countdown has already been initiated
    var RoomActiveMap : [int]logic = map{}

    # -------------------------------------------------------------------------
    # INITIALIZATION & LIFECYCLE
    # -------------------------------------------------------------------------
    OnBegin<override>()<suspends> : void =
        TestButton.InteractedWithEvent.Subscribe(OnTestButtonPressed)
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)

        for (Player : GetPlayspace().GetPlayers()):
            InitializePlayer(Player)

    OnPlayerAdded(Player : agent) : void =
        InitializePlayer(Player)

    InitializePlayer(Player : agent) : void =
        if (set PlayerCurrentRoom[Player] = 0):
            RegisterPlayerInRoom(Player, 0)
            
            # Spawn asynchronous loop to monitor this player's eliminations across respawns
            spawn{ MonitorPlayerEliminations(Player) }

    OnTestButtonPressed(Agent : agent) : void =
        AdvancePlayerRoom(Agent)

    # -------------------------------------------------------------------------
    # CORE GAMEPLAY LOGIC
    # -------------------------------------------------------------------------
    MonitorPlayerEliminations(Player : agent)<suspends> : void =
        loop:
            if (FortChar := Player.GetFortCharacter[]):
                ElimResult := FortChar.EliminatedEvent().Await()
                
                if (KillerChar := ElimResult.EliminatingCharacter?):
                    if (KillerAgent := KillerChar.GetAgent[]):
                        AdvancePlayerRoom(KillerAgent)
                
                Sleep(1.0) # Buffer for respawn sequence
            else:
                Sleep(0.2) # Await valid character body

    AdvancePlayerRoom(Agent : agent) : void =
        if (CurrentRoomIndex := PlayerCurrentRoom[Agent]):
            if (CurrentRoomIndex < RoomTeleporters.Length, TargetTeleporter := RoomTeleporters[CurrentRoomIndex]):
                NewRoomIndex := CurrentRoomIndex + 1
                
                if (set PlayerCurrentRoom[Agent] = NewRoomIndex):
                    # Strip previous weapon to ensure unarmed waiting phase
                    WeaponStripper.Remove(Agent)
                    TargetTeleporter.Teleport(Agent)
                    
                    # Register arrival in new room (weapons withheld until countdown completes)
                    RegisterPlayerInRoom(Agent, NewRoomIndex)
                    Print("Player advanced to Room {NewRoomIndex + 1}!")
            else:
                HandleVictory(Agent)

    # -------------------------------------------------------------------------
    # ROOM SYNCHRONIZATION
    # -------------------------------------------------------------------------
    RegisterPlayerInRoom(Agent : agent, RoomIndex : int) : void =
        CurrentCount := GetPlayersInRoomCount(RoomIndex)
        NewCount := CurrentCount + 1
        
        if (set PlayersInRoomCount[RoomIndex] = NewCount):
            TotalPlayers := GetPlayspace().GetPlayers().Length
            
            # Trigger synchronization countdown once all active players are present
            if (NewCount >= TotalPlayers):
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

    # -------------------------------------------------------------------------
    # INVENTORY & UTILITY
    # -------------------------------------------------------------------------
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