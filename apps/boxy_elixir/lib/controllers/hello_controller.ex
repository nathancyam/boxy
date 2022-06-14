defmodule BoxyElixir.HelloController do
  alias :grpcbox_stream, as: GrpcBoxStream

  def hello(ctx, request) do
    {:ok, %{response: "Welcome #{request.name}"}, ctx}
  end

  def greet(_message, stream) do
    Enum.each(1..10, fn count ->
      IO.inspect("sending #{count}")
      GrpcBoxStream.send(%{response: "Hello #{count}"}, stream)
      Process.sleep(5_000)
    end)

    :ok
  end
end
