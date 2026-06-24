# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule FabricPlatformCentral.Updater do
  @moduledoc """
  Installs and updates client, server, and self via casync delta downloads.

  Self-update bootstrap pattern: the base MSIX is released once. When it
  runs update(:self, ...) it downloads the newer Burrito exe to a mutable
  location (%LOCALAPPDATA%/FabricPlatformCentral/), spawns it, and exits.
  The new exe continues this pattern for all future releases — no new MSIX
  is ever required.
  """

  require Logger

  @cdn_base "https://raw.githubusercontent.com/v-sekai-multiplayer-fabric/fabric-casync-central/main"
  @releases_base "https://github.com/v-sekai-multiplayer-fabric"
  @self_exe "fabric-platform-central.exe"

  # Each target maps to {github_releases_repo, caibx_asset_name, cdn_store_path}.
  # The .caibx index ships as a GitHub Release asset; chunks live in the CDN repo.
  @targets %{
    client: {@releases_base <> "/godot-loop-slice", "loop-slice.caibx", @cdn_base <> "/client"},
    server:
      {@releases_base <> "/godot-loop-slice", "loop-slice-server.caibx", @cdn_base <> "/server"},
    self:
      {@releases_base <> "/fabric-platform-central", "fabric-platform-central.caibx",
       @cdn_base <> "/self"}
  }

  @doc """
  Update *target* from the latest GitHub release.

  For :client and :server, downloads to install_dir and returns :ok.
  For :self, downloads the new exe, spawns it, then halts the current
  process — this function does not return on success.
  """
  def update(target, install_dir, opts \\ []) when target in [:client, :server, :self] do
    {repo_base, index_file, store_url} = @targets[target]
    Logger.info("Checking #{target} update from #{repo_base}")

    with {:ok, tag} <- latest_tag(repo_base, opts),
         index_url = "#{repo_base}/releases/download/#{tag}/#{index_file}",
         output_dir = output_dir(install_dir, target),
         :ok <- File.mkdir_p(output_dir),
         {:ok, _} <-
           AriaStorage.CasyncDecoder.decode_uri(index_url,
             store_uri: store_url,
             output_dir: output_dir,
             verify_integrity: true,
             progress_callback: &log_progress/2
           ) do
      if target == :self, do: handoff(output_dir), else: :ok
    end
  end

  # Replace the running process with the newly downloaded exe.
  # The new exe inherits no state — it starts fresh and re-enters the
  # same update loop on its next run.
  defp handoff(output_dir) do
    new_exe = Path.join(output_dir, @self_exe)

    unless File.exists?(new_exe) do
      {:error, "downloaded exe not found at #{new_exe}"}
    else
      Logger.info("Handing off to #{new_exe}")
      Port.open({:spawn_executable, new_exe}, [:binary, :nouse_stdio])
      System.stop(0)
    end
  end

  defp output_dir(install_dir, :self) do
    # Write to a sibling directory so the running exe is never overwritten
    # while in use. The new exe writes to the same location on its next
    # self-update, naturally replacing the previous download.
    Path.join([install_dir, "self", "bin"])
  end

  defp output_dir(install_dir, target), do: Path.join(install_dir, to_string(target))

  defp latest_tag(repo_base, _opts) do
    api_url =
      repo_base
      |> String.replace("https://github.com/", "https://api.github.com/repos/")
      |> Kernel.<>("/releases/latest")

    case Req.get(api_url, headers: [{"accept", "application/vnd.github+json"}]) do
      {:ok, %{status: 200, body: %{"tag_name" => tag}}} -> {:ok, tag}
      {:ok, %{status: status}} -> {:error, "GitHub API returned #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp log_progress(done, remaining) do
    total = done + remaining
    pct = if total > 0, do: round(done * 100 / total), else: 0
    Logger.info("  chunks #{done}/#{total} (#{pct}%)")
  end
end
