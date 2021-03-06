defmodule Core do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Fill initial cache
    Cosmic.fetch_all()
    Core.Jobs.EventCache.fetch_or_load()

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      # supervisor(Core.Repo, []),
      # can be readded when we have a database

      # Start the endpoint when the application starts
      supervisor(Core.Endpoint, []),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)

    {:ok, _conn} = Redix.start_link(Application.get_env(:core, :redis_url), name: :redix)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Core.Endpoint.config_change(changed, removed)
    :ok
  end
end
