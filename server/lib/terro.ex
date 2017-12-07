defmodule Terro do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    Logger.info "Starting server"

    children = [
      worker(Terro.PlayerGameRegistry, []),
      supervisor(Terro.Endpoint, []),
      supervisor(Terro.GameSupervisor, []),
      worker(Terro.PlayerQueue, [2])
    ]

    opts = [strategy: :one_for_one, name: Terro.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Terro.Endpoint.config_change(changed, removed)
    :ok
  end
end
