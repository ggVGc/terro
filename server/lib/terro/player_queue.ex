defmodule Terro.PlayerQueue do
  use GenServer
  require Logger

  def start_link(players_per_game) do
    init_state = %{
      queue: [], 
      size: players_per_game
    }
    Agent.start_link fn -> init_state end, name: __MODULE__ 
  end


  def push(player, game_start_callback) do
    Agent.update __MODULE__, fn old_state ->
      state = %{old_state | :queue => [player | old_state.queue]}

      cond do
        state.size == length(state.queue) ->
          Logger.info "Queue full, starting a game"
          game_start_callback.(state.queue)
          Logger.info "Started a new game with #{state.size} players"
          %{state | :queue => []}
        true ->
          state
        end
    end
  end


  def remove(playerId) do
    Agent.update __MODULE__, fn state ->
      %{state |
        :queue => Enum.reduce(state.queue, [], fn(candidate, acc) ->
          if candidate.id == playerId do
            acc
          else
            [candidate | acc]
          end
        end)
      }
    end
  end
end
