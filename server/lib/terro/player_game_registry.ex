defmodule Terro.PlayerGameRegistry do
  # Maps player IDs to game IDs, and kills games if any player leaves
  
  require Logger

  @moduledoc """
  Stores the currently running game logic pids per player_id.
  """
  def start_link do
    Agent.start_link fn -> Map.new end, name: __MODULE__
  end

  def put(player_id, pid) do
    Agent.update __MODULE__, fn dict -> Map.put(dict, player_id, pid) end
  end

  def get(player_id) do
    Agent.get __MODULE__, fn dict -> Map.get(dict, player_id) end
  end

  def remove(player_id, nick) do
    Agent.update __MODULE__, fn dict ->
      game_pid = Map.get(dict, player_id)
      if game_pid do
        # player is part of a game.
        # Tell other players about it, and kill the game
        if Process.alive?(game_pid) do
          GenServer.cast(game_pid, {:player_left, {player_id, nick}})
        end
      end
      Map.delete(dict, player_id)
    end
  end
end

