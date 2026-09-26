using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Simulation }

gauntlet_manager := class(creative_device):

    @editable
    RoomTeleporters : []teleporter_device = array{}

    @editable
    TestButton : button_device = button_device{}

    var PlayerCurrentRoom : [agent]int = map{}

    OnBegin<override>()<suspends>:void =
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)

        # TestButton.InteractedWithEvent.Subscribe(OnTestButtonPressed)

        for (Player : GetPlayspace().GetPlayers()):
            InitializePlayer(Player)

    OnPlayerAdded(Player : agent):void =
        InitializePlayer(Player)

    InitializePlayer(Player : agent):void =
        if (set PlayerCurrentRoom[Player] = 0):
            # Initialization logic placeholder
            false

    <# OnTestButtonPressed(Agent : agent) : void =
        Print("Test button pressed! Advancing room...")
        AdvancePlayerRoom(Agent) #>

    AdvancePlayerRoom(Agent : agent) : void =
        if (CurrentRoomIndex := PlayerCurrentRoom[Agent]):
            # Use the CurrentRoomIndex to grab the corresponding teleporter
            if (CurrentRoomIndex < RoomTeleporters.Length, TargetTeleporter := RoomTeleporters[CurrentRoomIndex]):
                NewRoomIndex := CurrentRoomIndex + 1
                
                if (set PlayerCurrentRoom[Agent] = NewRoomIndex):
                    TargetTeleporter.Teleport(Agent)
            else:
                # If there are no teleporters left, they win
                HandleVictory(Agent)

    HandleVictory(Agent : agent) : void =
        Print("We have a winner!")