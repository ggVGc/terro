defmodule Terro.RoomChannel do
  use Phoenix.Channel
  require Logger

  def join("rooms:lobby", _message, socket) do
    Process.flag(:trap_exit, true)

    {:ok, socket}
  end


  # def join("rooms:game:" <> gameID, _message, socket) do
  def join("rooms:game", message, socket) do
    # Logger.info "Tried joining game: #{gameID}"

    Logger.info(inspect message)
    send(self(), {:after_join_game, %{}})
    nick = message["nick"]
    {:ok, assign(socket, :player_nick, nick)}
  end


  def join("rooms:" <> _, _message, _socket) do
    {:error, %{reason: "unauthorized"}}
  end


  def on_game_start(game_players) do
    game_pid = Terro.GameSupervisor.start_game game_players

    Enum.each(game_players, fn player ->
      Terro.PlayerGameRegistry.put(player.id, game_pid)
    end)
  end


  def handle_info({:after_join_game, msg}, socket) do
    player = %{
      socket: socket, 
      id: Utils.get_unique_id,
      nick: socket.assigns.player_nick
    }

    Terro.PlayerQueue.push(player, &on_game_start/1)

    {:noreply, assign(socket, :player_id, player.id)}
  end


  def terminate(reason, socket) do
    Logger.debug"> leave #{inspect reason}"
    player_id = socket.assigns.player_id
    nick = socket.assigns.player_nick

    # If player has already joined a game, this does nothing
    # Otherwise player gets droped from queue
    Terro.PlayerQueue.remove(player_id)
    Terro.PlayerGameRegistry.remove(player_id, nick)
    :ok
  end


  def handle_in("click", msg, socket) do
    # broadcast! socket, "new:msg", %{user: msg["user"], body: msg["body"]}
    player_id = socket.assigns.player_id
    game_pid = Terro.PlayerGameRegistry.get(player_id)
    GenServer.cast(game_pid, {:click, {player_id, msg["value"]}})
    {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  end

end
