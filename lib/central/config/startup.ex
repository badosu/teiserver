defmodule Central.Config.Startup do
  @moduledoc false
  use CentralWeb, :startup

  def startup do
    QuickAction.add_items([
      %{
        label: "Preferences",
        icons: ["far fa-cog", :edit],
        url: "/config/user",
        keywords: ["Settings"]
      }
    ])
  end
end
