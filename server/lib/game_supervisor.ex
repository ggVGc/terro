defmodule Terro.GameSupervisor do
  use Supervisor
  require Logger
  

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  def start_game(players) do
    [p1, p2] = players
    Logger.debug "GameSupervisor - start_game, p1: #{p1.id}, p2: #{p2.id}"
    {:ok, pid} = Supervisor.start_child(__MODULE__, [players])
    pid
  end

  def init(:ok) do
    Logger.info "GameSupervisor init"
    Supervisor.init([Terro.TerroGame], strategy: :simple_one_for_one)
  end

end
