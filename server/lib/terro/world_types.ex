defmodule WorldState do
  require Constants
  defstruct [
    spawners: [],
    defenses: [],
    fighters: [],
    player_states: %{},
    resource_slots: Constants.init_resource_slots,

    players: [],
    id_counter: 0
  ]
end

defmodule Building do
  def _init(health)do
    [health: health,
     pos: {0,0},
     id: 0,
     owner: 0]
  end
end

defmodule SpawnerBuilding do
  require Constants
  defstruct Building._init(Constants.spawner_health)++[
    spawn_timer: 0
  ]
end

defmodule DefenseBuilding do
  require Constants
  defstruct Building._init(Constants.defense_health)
end


defmodule Fighter do
  defstruct [
    pos: {0,0},
    dir: {1,0},
    owner: 0,
    life_time: 0,
    id: 0
  ]
end


defmodule PlayerState do
  require Constants
  defstruct [
    credits: Constants.initial_credits
  ]
end

