{ self
, steam-fetcher
,
}: { config
   , pkgs
   , lib
   , ...
   }:
let
  cfg = config.services.valheim;
  stateDir = "/var/lib/valheim";
in
{
  options.services.valheim = {
    enable = lib.mkEnableOption (lib.mdDoc "Valheim Dedicated Server");

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "Some Cozy Server";
      description = lib.mdDoc "The name listed in the server browser.";
    };

    worldName = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "Midgard";
      description = lib.mdDoc ''
        The name of the world file to use, without the extension.
        If the world does not exist, then the server will generate a world from
        a random seed.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2456;
      description = lib.mdDoc ''
        The port on which to listen for incoming connections.

        Note that the port just above this one will be used for the Steam server browser service.
      '';
    };

    crossplay = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc ''
        Whether to enable cross-platform players.

        See the [announcement](https://steamcommunity.com/games/892970/announcements/detail/3308480236523722724)
        for details on this feature.

        This should be disabled when using a modded server that requires the
        client to be modded, as only PC versions can run mods.
      '';
    };

    noGraphics = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc ''
        Whether to run with graphics or not.
        Enable this if you're headless with no GPU.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Whether to open ports in the firewall.";
    };

    public = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = lib.mdDoc ''
        Toggles visibility on the Steam server & community lists.

        When not set, defaults to true (visible).
        Set to false to make the server private.
      '';
    };

    preset = lib.mkOption {
      type = with lib.types; nullOr (enum [ "easy" "hard" "hardcore" "casual" "hammer" "immersive" ]);
      default = null;
      example = "hardcore";
      description = lib.mdDoc ''
        The preset world modifier, valid options are
        "easy", "hard", "hardcore", "casual", "hammer" and "immersive".
      '';
    };

    password = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = lib.mdDoc ''
        The server password.

        This is passed as a commandline argument to the server, so it
        can be viewed by any user on the system able to list processes.
      '';
    };

    passwordEnvFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "/var/lib/valheim/password.env";
      description = lib.mdDoc ''
        Path to a file containing the server password in env format.

        Example:
        VH_SERVER_PASSWORD='myp@$$'
      '';
    };

    adminList = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "72057602627862526"
        "72057602627862527"
      ];
      description = lib.mdDoc ''
        List of Steam IDs to be added to the adminlist.txt file.

        These users will have admin privileges on the server.
      '';
    };

    adminListFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "/var/lib/valheim/adminlist.txt";
      description = lib.mdDoc ''
        A file containing a list of Steam IDs to be appended to the adminlist.txt file.

        These users will have admin privileges on the server.
      '';
    };

    permittedList = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "72057602627862526"
        "72057602627862527"
      ];
      description = lib.mdDoc ''
        List of Steam IDs to be added to the permittedlist.txt file.

        Only these users will be allowed to join the server if the list is not empty.
        If you use this, all players not on the list will be unable to join.
      '';
    };

    permittedListFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "/var/lib/valheim/permittedlist.txt";
      description = lib.mdDoc ''
        A file containing a list of Steam IDs to be appended to the permittedlist.txt file.

        Only these users will be allowed to join the server if the list is not empty.
        If you use this, all players not on the list will be unable to join.
      '';
    };

    bannedList = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "72057602627862526"
        "72057602627862527"
      ];
      description = lib.mdDoc ''
        List of Steam IDs to be added to the bannedlist.txt file.

        These users will be banned from the server.
      '';
    };

    bannedListFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "/var/lib/valheim/bannedlist.txt";
      description = lib.mdDoc ''
        A file containing a list of Steam IDs to be appended to the bannedlist.txt file.

        These users will be banned from the server.
      '';
    };

    bepinexMods = lib.mkOption {
      type = with lib; types.listOf types.package;
      default = [ ];
      description = "BepInEx mods to install.";
      example = lib.types.literalExpression ''
        [
          (pkgs.fetchValheimThunderstoreMod {
            owner = "Somebody";
            name = "SomeMod";
            version = "x.y.z";
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          })
        ]
      '';
    };

    bepinexConfigs = lib.mkOption {
      type = with lib; types.listOf types.path;
      default = [ ];
      description = ''
        Config files for BepInEx mods.

        The filename must be what the given mod is expecting, otherwise it will
        not be loaded.
      '';
      example = lib.types.literalExpression ''
        [
          ./some_mod.cfg
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ self.overlays.default steam-fetcher.overlays.default ];

    users = {
      users.valheim = {
        isSystemUser = true;
        group = "valheim";
        home = stateDir;
        createHome = true;
      };
      groups.valheim = { };
    };

    systemd.services =
      let
        installDir = "${stateDir}/valheim-server-modded";
        # If passwordEnvFile is provided then use environment variable, else insert password in unit file directly.
        # Assertions ensure that other cases are not possible.
        serverPassword = if cfg.passwordEnvFile != null then "\"\${VH_SERVER_PASSWORD}\"" else cfg.password;
      in
      {
        valheim = {
          description = "Valheim dedicated server";
          requires = [ "network.target" ];
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          preStart =
            let
              mods = pkgs.symlinkJoin {
                name = "valheim-bepinex-mods";
                paths = cfg.bepinexMods;
                postBuild = ''
                  rm -f \
                    "$out"/*.md \
                    "$out"/icon.png \
                    "$out"/manifest.json
                '';
              };
              modConfigs =
                pkgs.runCommandLocal "valheim-bepinex-configs"
                  {
                    configs = cfg.bepinexConfigs;
                  } ''
                  mkdir "$out"
                  for cfg in $configs; do
                    cp $cfg $out/$(stripHash $cfg)
                  done
                '';
              createListFile = name: list: ''
                echo "// List of Steam IDs for ${name} ONE per line
                ${lib.strings.concatStringsSep "\n" list}" > ${stateDir}/.config/unity3d/IronGate/Valheim/${name}
                chown valheim:valheim ${stateDir}/.config/unity3d/IronGate/Valheim/${name}
              '';
              concatListFile = name: file: ''
                cat ${file} >> ${stateDir}/.config/unity3d/IronGate/Valheim/${name}
              '';
            in
            ''
              mkdir -p ${stateDir}/.config/unity3d/IronGate/Valheim
              ${createListFile "adminlist.txt" cfg.adminList}
              ${createListFile "permittedlist.txt" cfg.permittedList}
              ${createListFile "bannedlist.txt" cfg.bannedList}
            ''
            + lib.optionalString (cfg.adminListFile) ''
              ${concatListFile "adminlist.txt" cfg.adminListFile}
            ''
            + lib.optionalString (cfg.permittedListFile) ''
              ${concatListFile "permittedList.txt" cfg.permittedListFile}
            ''
            + lib.optionalString (cfg.bannedListFile) ''
              ${concatListFile "bannedlist.txt" cfg.bannedListFile}
            ''
            + lib.optionalString (cfg.bepinexMods != [ ]) ''
              if [ -e ${installDir} ]; then
                chmod -R +w ${installDir}
                rm -rf ${installDir}
              fi
              mkdir ${installDir}
              cp -r \
                ${pkgs.valheim-server-unwrapped}/* \
                ${pkgs.valheim-bepinex-pack}/* \
                ${installDir}

              # BepInEx doesn't like read-only files.
              chmod -R u+w ${installDir}
            ''
            + lib.optionalString (cfg.bepinexMods != [ ]) ''
              # Install extra mods.
              cp -rL "${mods}"/. ${installDir}/BepInEx/plugins/

              # BepInEx *really* doesn't like *any* read-only files.
              chmod -R u+w ${installDir}/BepInEx/plugins/
            ''
            + lib.optionalString (cfg.bepinexConfigs != [ ]) ''
              # Install extra mod configs.
              cp -r ${modConfigs}/. ${installDir}/BepInEx/config/

              # BepInEx *really* doesn't like *any* read-only files.
              chmod -R u+w ${installDir}/BepInEx/config/
            '';

          serviceConfig =
            let
              valheimBepInExFHSEnvWrapper = pkgs.buildFHSEnv {
                name = "valheim-server";
                runScript = pkgs.writeScript "valheim-server-bepinex-wrapper" ''
                  # Whether or not to enable Doorstop. Valid values: TRUE or FALSE
                  export DOORSTOP_ENABLE=TRUE

                  # What .NET assembly to execute. Valid value is a path to a .NET DLL that mono can execute.
                  export DOORSTOP_INVOKE_DLL_PATH="${installDir}/BepInEx/core/BepInEx.Preloader.dll"

                  # Which folder should be put in front of the Unity dll loading path
                  export DOORSTOP_CORLIB_OVERRIDE_PATH="${installDir}/unstripped_corlib"

                  export LD_LIBRARY_PATH=${installDir}/doorstop_libs:$LD_LIBRARY_PATH
                  export LD_PRELOAD="libdoorstop_x64.so"

                  export LD_LIBRARY_PATH=${pkgs.steamworks-sdk-redist}/lib:$LD_LIBRARY_PATH
                  export SteamAppId=892970

                  exec ${installDir}/valheim_server.x86_64 "$@"
                '';

                targetPkgs = with pkgs;
                  pkgs: [
                    pkgs.steamworks-sdk-redist
                    zlib
                    pulseaudio
                  ];
              };
            in
            {
              Type = "exec";
              User = "valheim";
              EnvironmentFile = lib.mkIf (cfg.passwordEnvFile != null) cfg.passwordEnvFile;
              ExecStart =
                let
                  valheimServerPkg =
                    if (cfg.bepinexMods != [ ])
                    then valheimBepInExFHSEnvWrapper
                    else pkgs.valheim-server;
                in
                lib.strings.concatStringsSep " " ([
                  "${valheimServerPkg}/bin/valheim-server"
                  "-name \"${cfg.serverName}\""
                  "-batchmode"
                ]
                ++ (lib.lists.optional (cfg.worldName != null) "-world \"${cfg.worldName}\"")
                ++ [
                  "-port \"${builtins.toString cfg.port}\""
                  "-password ${serverPassword}"
                  "-public ${if cfg.public then "1" else "0"}"
                ]
                ++ (lib.lists.optional cfg.crossplay "-crossplay")
                ++ (lib.lists.optional (cfg.preset != null) "-preset \"${cfg.preset}\"")
                ++ (lib.lists.optional cfg.noGraphics "-nographics"));
            };
        };
      };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [
        cfg.port
        (cfg.port + 1) # Steam server browser
      ];
    };

    assertions = [
      {
        assertion = cfg.serverName != "";
        message = "The server name must not be empty.";
      }
      {
        assertion = cfg.worldName != "";
        message = "The world name must not be empty.";
      }
      {
        assertion = (cfg.password != null && cfg.password != "") != (cfg.passwordEnvFile != null);
        message = "Please provide either password or passwordEnvFile but not both";
      }
    ];
  };
}
