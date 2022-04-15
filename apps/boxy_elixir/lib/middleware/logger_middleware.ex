defmodule BoxyElixir.LoggingMiddleware do
  require Logger

  def log(ctx, req, server_info, handler) do
    Logger.metadata(
      method: server_info.full_method,
      service: server_info.service
    )

    start = System.monotonic_time()
    res = handler.(ctx, req)
    duration = System.monotonic_time() - start
    Logger.info("#{server_info.full_method} took #{duration(duration)}")
    res
  end

  defp duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if duration > 1000 do
      duration_str =
        duration
        |> div(1000)
        |> Integer.to_string()

      duration_str <> "ms"
    else
      Integer.to_string(duration) <> "µs"
    end
  end
end
