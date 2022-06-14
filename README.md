# Boxy: A Elixir gRPC project using `grpcbox`

## Introduction

This repository is an example of a Elixir gRPC service that uses `grpcbox`, a Erlang gRPC library. There aren't many examples demonstrating how this is done, so this example is a very naive attempt to utilise `grpcbox` as the main gRPC plumbing, while we can write our business/controller logic in Elixir.

## Requirements

- Erlang
- Elixir

Some prior knowledge on how Elixir maps to Erlang is required.

## Project Layout

This project uses the umbrella project pattern, which allows us to house the `.erl` as well as the `.ex` files in one location. `grpcbox` has a sibling project called `grpcbox_plugin`, utilised to generate the Erlang gRPC stub files/modules. We need to refer to these modules in our Elixir configuration, typically found in `config/config.exs`.

To get started we need to start an umbrella project:

```bash
$ mix new boxy --umbrella --sup
```

This will create the `apps` directory, in which we need to create two applications:

- The Elixir application that will actually run the gRPC server via `grpcbox`.
- The Erlang application that is primarily used to build the gRPC stub files.

In our `apps` directory, we need to run the following:

```bash
$ mix new boxy_elixir --sup
```

And

```bash
$ rebar3 new app boxy_erlang
```

### Erlang project

In our `boxy_erlang` project, we need to define a number of dependencies in `rebar.config`:

```
{erl_opts, [debug_info]}.
{deps, [grpcbox]}.

{grpc, [{protos, "protos"},
  {gpb_opts, [{module_name_suffix, "_pb"}]}]}.

{plugins, [grpcbox_plugin]}.

{shell, [
  % {config, "config/sys.config"},
    {apps, [boxy_erlang]}
]}.
```

The `grpcbox` library will be used to generate our Erlang protobuf stubs via `grpcbox_plugin` which adds a `rebar3 grpc gen` command.

Let's get started by generating our Erlang stubs. Provided that we have a `.proto` file like this in `boxy/apps/boxy_erlang/proto/`:

```protobuf
syntax = "proto3";

package example;

service HelloService {
  rpc Hello(HelloRequest) returns (HelloResponse);
  rpc Greet(GreetRequest) returns (stream GreetResponse);
}

message GreetRequest {
  string name = 1;
}

message GreetResponse {
  string response = 1;
}

message HelloRequest {
  string name = 1;
}

message HelloResponse {
  string response = 1;
}
```

Running `rebar3 grpc gen` should generate our Erlang stubs as follows:

```bash
$ cd apps/boxy_erlang
$ rebar3 grpc gen
===> Writing /.../boxy_erlang/src/hello_world_pb.erl
```

> This might complain about not being able to write to a `_build` directory in the `boxy_erlang` directory.

Now that we have our protobuf Erlang modules, we can access it in Elixir as `:hello_world_pb`. We can also utilise `alias ..., as: ...` to make it more idiomatic.

### Elixir project

In `boxy_elixir`, we need to add a couple of dependencies,

```elixir
# mix.exs
  defp deps do
    [
      {:grpcbox, "~> 0.15.0"},
      {:chatterbox,
       git: "https://github.com/tsloughter/chatterbox.git", tag: "v0.12.0", override: true},
      {:boxy_erlang, in_umbrella: true, manager: :rebar3}
    ]
  end
```

- `grpcbox` contains the code necessary to start a gRPC server.
- `chatterbox` is the HTTP/2 library used by `grpcbox`.
- `boxy_erlang` is a sibling application, used to house the Erlang stub files.

Run `mix deps.get` to get our dependencies. Next, we generate our configuration in the umbrella configuration that maps to the `grpcbox` `sys.config` configuration:

```
# config/config.exs

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
```

We can map the protobuf service definitions to our Elixir controller: `BoxyElixir.HelloController`. This allows us to utilise Elixir code at the edge of our business logic. A controller can look something like this:

```elixir
defmodule BoxyElixir.HelloController do
  def hello(ctx, request) do
    {:ok, %{response: "Welcome #{request.name}"}, ctx}
  end

  def greet(_message, stream) do
    Enum.each(1..10, fn count ->
      IO.inspect("sending #{count}")
      :grpcbox_stream.send(%{response: "Hello #{count}"}, stream)
      Process.sleep(5_000)
    end)

    :ok
  end
end
```

We're still bound by the callbacks that are specified in the `:grpcbox` implementation, but we can return maps and lists that represent our response types. Last by not least, we need to start the `:grpcbox` supervisor in our application supervision tree:

```elixir
defmodule BoxyElixir.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # An application can host multiple servers, so we need to generate a child spec
    # for each entry
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

  defp servers, do: Application.get_env(:boxy_elixir, :servers)

  # A simple wrapper on top of the `:grpcbox` module to define our server child specs.
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
```

## Starting the server

We can start the gRPC server by running the application as you normally would:

```bash
$ iex -S mix
```

Provided that you have a logger interceptor defined, making gRPC requests to this endpoint should result in a response.
