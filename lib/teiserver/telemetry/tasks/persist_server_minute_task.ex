defmodule Teiserver.Telemetry.Tasks.PersistServerMinuteTask do
  use Oban.Worker, queue: :teiserver

  alias Teiserver.Telemetry

  @impl Oban.Worker
  def perform(_) do
    now = Timex.now() |> Timex.set([microsecond: 0])

    case Telemetry.get_server_minute_log(now) do
      nil ->
        perform_telemetry_persist(now)
        :ok

      _ ->
        # Log has already been added
        :ok
    end
  end

  defp perform_telemetry_persist(timestamp) do
    data = Telemetry.get_totals_and_reset()
      |> Map.drop([:cycle])

    Telemetry.create_server_minute_log(%{
      timestamp: timestamp,
      data: data
    })
  end
end
