{
  description = "WR Project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";

    zephyr.url = "github:zephyrproject-rtos/zephyr/v4.3.0";
    zephyr.flake = false;

    zephyr-nix.url = "github:nix-community/zephyr-nix";
    zephyr-nix.inputs.nixpkgs.follows = "nixpkgs";
    zephyr-nix.inputs.zephyr.follows = "zephyr";

    flake-utils.url = "github:numtide/flake-utils";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs =
          let
            config = {
              allowUnfreePredicate =
                pkg:
                builtins.elem (lib.getName pkg) [
                  "segger-jlink"
                  "segger-jlink"
                  "nrfutil"
                  "nrfutil-device"
                  "nrfutil-trace"
                  "nrfutil-ble-sniffer"
                  "nrfutil-completion"
                  "nrfutil-mcu-manager"
                  "nrfutil-npm"
                  "nrfutil-nrf5sdk-tools"
                  "nrfutil-sdk-manager"
                  "nrfutil-suit"
                  "nrfutil-toolchain-manager"
                  "nrf-command-line-tools"
                ];
              segger-jlink.acceptLicense = true;
              permittedInsecurePackages = [
                "segger-jlink-qt4-874"
              ];
            };
          in
          import nixpkgs {
            inherit config system;
            overlays = [
              (self: super: {
                pythonPackages = super.pythonPackages // {
                  gitlint-core = super.pythonPackages.gitlint;
                };
              })
            ];
          };
        inherit (pkgs) lib;
        inherit (pkgs.pkgsi686Linux) SDL2; # for 32-bit libs needed by native_sim
        zephyr-packages = inputs.zephyr-nix.packages.${system};
        zephyr-sdk = zephyr-packages.sdk.override {
          targets = [
            "arm-zephyr-eabi"
            "xtensa-espressif_esp32s3_zephyr-elf"
            "riscv64-zephyr-elf"
          ];
        };
        zephyr-python-env = zephyr-packages.pythonEnv.override {
          extraPackages =
            ps: with ps; [
              pykwalify
            ];
        };
        zephyr-env = pkgs.symlinkJoin {
          name = "zephyr-env";
          meta.mainProgram = "west";
          nativeBuildInputs = with pkgs; [
            makeWrapper
          ];
          paths = [
            zephyr-sdk
            zephyr-packages.pythonEnv
            zephyr-packages.hosttools-nix
            SDL2
          ]
          ++ (with pkgs; [
            cmake
            ninja
            binutils
            gdb
            pkg-config

            # openocd
            segger-jlink # -headless
            stlink # st-flash, st-info, st-util
            dfu-util
            pyocd
            bossa
            nrfutil
            (nrfutil.withExtensions [
              "nrfutil-device"
              "nrfutil-trace"
              "nrfutil-ble-sniffer"
              "nrfutil-completion"
              "nrfutil-mcu-manager"
              "nrfutil-npm"
              "nrfutil-nrf5sdk-tools"
              "nrfutil-sdk-manager"
              "nrfutil-suit"
              "nrfutil-toolchain-manager"
            ])
            nrf-command-line-tools
            esptool
          ]);
          postBuild = ''
            wrapProgram "$out/bin/west" \
              --prefix PATH : $out/bin \
              --prefix PKG_CONFIG_PATH : "${SDL2.dev}/lib/pkgconfig" \
              --prefix LD_LIBRARY_PATH : "${SDL2.out}/lib" \
              --prefix CMAKE_PREFIX_PATH : ${zephyr-sdk}/cmake \
              --set ZEPHYR_TOOLCHAIN_VARIANT zephyr
          '';
        };
        init-script = pkgs.writeShellApplication {
          name = "init-script";
          runtimeInputs = [
            zephyr-env
          ]
          ++ (with pkgs; [
            git
            jq
            diffutils
          ]);
          text = builtins.readFile ./scripts/init-and-chores.sh;
        };
      in
      {
        packages = {
          inherit zephyr-env;
        };
        apps = {
          init = {
            type = "app";
            program = "${init-script}/bin/init-script";
          };
          west = {
            type = "app";
            program = "${zephyr-env}/bin/west";
          };
        };
        formatter =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            config = self.checks.${system}.pre-commit-check.config;
            inherit (config) package configFile;
            script = ''
              ${pkgs.lib.getExe package} run --all-files --config ${configFile}
            '';
          in
          pkgs.writeShellScriptBin "pre-commit-run" script;
        checks = {
          pre-commit-check = inputs.git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixfmt-rfc-style.enable = true;
              shfmt.enable = false;
              shfmt.settings.simplify = true;
              shellcheck.enable = true;
              typos.enable = true;
              cmake-format.enable = false;
              clang-format.enable = true;
              clang-tidy.enable = false;
            };
          };
          shell-fmt-check =
            let
              pkgs = inputs.nixpkgs.legacyPackages."${system}";
              files = pkgs.lib.concatStringsSep " " [
                "scripts/init-and-chores.sh"
              ];
            in
            pkgs.stdenv.mkDerivation {
              name = "shell-fmt-check";
              src = ./.;
              doCheck = true;
              nativeBuildInputs = with pkgs; [
                shfmt
              ];
              checkPhase = ''
                shfmt -d -s -i 4 -ci ${files}
              '';
              installPhase = ''
                mkdir "$out"
              '';
            };
        };
        devShells.default =
          let
            inherit (self.checks.${system}.pre-commit-check) shellHook enabledPackages;
          in
          pkgs.mkShell {
            packages = [
              zephyr-env
              init-script
            ]
            ++ enabledPackages;
            shellHook = ''
              ${shellHook}
              source <(west completion bash)
            '';
          };
      }
    ));
}
