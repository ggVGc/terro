defmodule Terro.TerroGame do
  use GenServer, restart: :temporary
  require Logger


  def start_link(_opts, players) do
    GenServer.start_link(__MODULE__, players)
  end


  def init(players) do
    Logger.debug "Initializing game state machine"
    {:ok, worldPid} = Terro.World.start_link players
    Logger.debug "Created world"


    state = %{players: players, world: worldPid}
    send_ids(state.players)
    send_opponent_nicks(state.players)

    {:ok, state}
  end


  defp send_ids(players) do
    Enum.map(players, fn(p) ->
      Phoenix.Channel.push(p.socket, "id", %{id: p.id})
    end)
  end


  defp send_opponent_nicks(players) do
    Enum.map(players, fn(target_player) ->
      names =
        Enum.filter(players, fn p -> target_player.id != p.id end)
        |> Enum.map(fn p -> p.nick end)
      Phoenix.Channel.push(target_player.socket, "opponents", %{names: names})
    end)
  end



  def handle_cast({:click, {player_id,[click_type, x, y]}}, state) do
    Logger.info "#{player_id}: click #{x}, #{y}"
    case click_type do
      0 -> Terro.World.place_spawner(state.world, [x,y], player_id)
      1 -> Terro.World.place_defense(state.world, [x,y], player_id)
    end
    {:noreply, state}
  end


  def handle_cast({:player_left, {player_id, nick}}, state) do
    Logger.warn "Player left. Game aborted"
    Enum.map(state.players, fn(p) ->
      if p.id != player_id do
        Phoenix.Channel.push(p.socket, "opponentLeft", %{name: nick})
      end
    end)
    {:stop, :shutdown, state}
  end

end
