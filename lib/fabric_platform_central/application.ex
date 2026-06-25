# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule FabricPlatformCentral.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Tray handles headless/no-display environments by returning :ignore from init.
    children = [FabricPlatformCentral.Tray]
    opts = [strategy: :one_for_one, name: FabricPlatformCentral.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
