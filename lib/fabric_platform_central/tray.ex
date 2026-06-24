# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule FabricPlatformCentral.Tray do
  @moduledoc """
  System tray icon using Erlang's built-in :wx (wxWidgets) binding.

  wxTaskBarIcon is part of OTP — no external dependency required.
  Events arrive as {:wx, id, obj, data, event} messages handled in handle_info/2.

  Menu actions:
    1 — Update Client
    2 — Update Server
    3 — Update Self
    99 — Quit
  """
  use GenServer
  require Logger

  # Wx is only compiled into OTP on systems with wxWidgets (Windows runtime target).
  # Suppress the undefined-module warning so Linux CI compiles clean.
  @compile {:no_warn_undefined, [Wx]}

  @menu_update_client 1
  @menu_update_server 2
  @menu_update_self 3
  @menu_quit 99

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    wx_env = :wx.new()
    tray = :wxTaskBarIcon.new()

    icon = load_icon()
    :wxTaskBarIcon.setIcon(tray, icon, tooltip: ~c"Fabric Platform Central")

    :wxTaskBarIcon.connect(tray, :taskbar_right_up)
    :wxTaskBarIcon.connect(tray, :command_menu_selected)

    {:ok, %{wx_env: wx_env, tray: tray, icon: icon}}
  end

  @impl true
  def handle_info({:wx, _id, _obj, _data, {:wxTaskBar, :taskbar_right_up}}, state) do
    menu = :wxMenu.new()
    :wxMenu.append(menu, @menu_update_client, ~c"Update Client")
    :wxMenu.append(menu, @menu_update_server, ~c"Update Server")
    :wxMenu.append(menu, @menu_update_self, ~c"Update Self")
    :wxMenu.appendSeparator(menu)
    :wxMenu.append(menu, @menu_quit, ~c"Quit")
    :wxTaskBarIcon.popupMenu(state.tray, menu)
    {:noreply, state}
  end

  def handle_info({:wx, @menu_quit, _obj, _data, _event}, state) do
    Logger.info("Quit requested from tray")
    System.stop(0)
    {:noreply, state}
  end

  def handle_info({:wx, @menu_update_client, _obj, _data, _event}, state) do
    run_update(:client)
    {:noreply, state}
  end

  def handle_info({:wx, @menu_update_server, _obj, _data, _event}, state) do
    run_update(:server)
    {:noreply, state}
  end

  def handle_info({:wx, @menu_update_self, _obj, _data, _event}, state) do
    run_update(:self)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    :wxTaskBarIcon.removeIcon(state.tray)
    :wxTaskBarIcon.destroy(state.tray)
    :wx.destroy()
  end

  defp load_icon do
    path = Application.app_dir(:fabric_platform_central, "priv/icon.png")

    if File.exists?(path) do
      bmp = :wxBitmap.new(:unicode.characters_to_list(path), type: Wx.const(:wxBITMAP_TYPE_PNG))
      icon = :wxIcon.new()
      :wxIcon.copyFromBitmap(icon, bmp)
      :wxBitmap.destroy(bmp)
      icon
    else
      :wxNullIcon
    end
  end

  defp run_update(target) do
    install_dir = Application.get_env(:fabric_platform_central, :install_dir)

    Task.start(fn ->
      case FabricPlatformCentral.Updater.update(target, install_dir) do
        :ok -> Logger.info("#{target} updated successfully")
        {:error, reason} -> Logger.error("#{target} update failed: #{inspect(reason)}")
      end
    end)
  end
end
