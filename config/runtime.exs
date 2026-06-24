import Config

config :fabric_platform_central,
  install_dir: System.get_env("FABRIC_INSTALL_DIR") || Path.join(System.user_home!(), ".fabric")
