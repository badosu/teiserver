defmodule Central.Admin.ToolLib do
  @moduledoc false
  use CentralWeb, :library

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:info)

  @spec icon :: String.t()
  def icon(), do: "far fa-tools"

  def coverage_colours(value) do
    cond do
      value < 5 -> :danger2
      value < 40 -> :danger
      value < 60 -> :warning2
      value < 75 -> :warning
      value < 85 -> :primary
      value < 100 -> :info
      true -> :success
    end
    |> Central.Helpers.StylingHelper.colours()
  end

  def get_oban_jobs() do
    query =
      from jobs in Oban.Job,
        where: jobs.state in ["scheduled", "available"]

    Repo.all(query)
  end
end
