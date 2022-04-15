defmodule BoxyElixir.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      for s <- servers(),
          do:
            grpc_child_spec(
              s.server_opts,
              s.grpc_opts,
              s.listen_opts,
              s.pool_opts,
              s.transport_opts
            )

    opts = [strategy: :one_for_one, name: BoxyElixir.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp servers do
    Application.get_env(:boxy_elixir, :servers)
  end

  defp grpc_child_spec(server_opts, grpc_opts, listen_opts, pool_opts, transport_opts) do
    :grpcbox.server_child_spec(
      server_opts || %{},
      grpc_opts(grpc_opts || %{}),
      listen_opts || %{},
      pool_opts || %{},
      transport_opts || %{}
    )
  end

  def grpc_opts(opts) do
    interceptors = opts.unary_interceptors || []

    Map.put(opts, :unary_interceptor, :grpcbox_chain_interceptor.unary(interceptors))
  end
end
