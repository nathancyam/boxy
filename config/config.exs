# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :boxy_elixir,
  client: %{
    channels: [
      default_channel: [
        {:http, "localhost", 8080, []},
        %{}
      ]
    ]
  },
  servers: [
    %{
      grpc_opts: %{
        service_protos: [:hello_world_pb],
        unary_interceptors: [&BoxyElixir.LoggingMiddleware.log/4],
        services: %{
          :"grpc.health.v1.Health" => :grpcbox_health_service,
          :"example.HelloService" => BoxyElixir.HelloController
        }
      },
      transport_opts: %{ssl: false},
      listen_opts: %{
        port: 8080,
        ip: {0, 0, 0, 0}
      },
      pool_opts: %{size: 50},
      server_opts: %{
        header_table_size: 4096,
        enable_push: 1,
        max_concurrent_streams: :unlimited,
        initial_window_size: 65535,
        max_frame_size: 16384,
        max_header_list_size: :unlimited
      }
    }
  ]

config :logger, :console,
  level: :info,
  format: "[$level] $date $time $metadata$message\n",
  metadata: [:user_id, :method, :service, :pid]
