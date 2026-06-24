# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule FabricPlatformCentral.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      case :os.type() do
        {:win32, _} -> [FabricPlatformCentral.Tray]
        _ -> []
      end

    opts = [strategy: :one_for_one, name: FabricPlatformCentral.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
