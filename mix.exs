# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule FabricPlatformCentral.MixProject do
  use Mix.Project

  def project do
    [
      app: :fabric_platform_central,
      version: "0.1.0-dev",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      mod: {FabricPlatformCentral.Application, []},
      extra_applications: [:logger, :crypto, :wx]
    ]
  end

  defp deps do
    [
      {:aria_storage, github: "V-Sekai-fire/aria-storage"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:burrito, "~> 1.0"}
    ]
  end

  defp releases do
    [
      fabric_platform_central: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            windows: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
