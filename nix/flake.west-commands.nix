{
  self,
  nixpkgs,
  flake-utils,
  ...
}@inputs:
system:
let
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (pkgs) lib;
  mkWestCommand =
    cmdName: args:
    pkgs.writeShellApplication {
      name = "west-${cmdName}";
      runtimeInputs = [
        self.packages.${system}.zephyr-env
      ];
      text = ''
        set -x
        west ${lib.concatStringsSep " " args} "$@"
      '';
    };
  mkWestBuildCommand =
    cmdName: args:
    mkWestCommand cmdName (
      [
        "build"
        "--pristine=auto"
      ]
      ++ args
    );
  mkWestBuildBoardCommand =
    board: cmdAppendix: args:
    let
      boardWithoutSlash = lib.replaceStrings [ "/" ] [ "_" ] board;
    in
    mkWestBuildCommand "${boardWithoutSlash}-build${cmdAppendix}" (
      [
        "--build-dir"
        "builds/${boardWithoutSlash}"
        "-b"
        board
      ]
      ++ args
    );
in
[
  (pkgs.writeShellScriptBin "west-build-for-board" ''
    set -ueo pipefail
    board="$1"
    shift
    ${mkWestBuildCommand "build-for-board" [ ]}/bin/west-build-for-board \
      --build-dir "builds/$(echo "$board" | sed 's%/%_%g')" \
      -b "$board" "$@"
  '')
  (mkWestBuildBoardCommand "xiao_nrf54l15/nrf54l15/cpuapp" "" [
    "--shield"
    "gpio_stepper_rail"
  ])
  (mkWestBuildBoardCommand "xiao_nrf54l15/nrf54l15/cpuapp" "-and-flash" [
    "--shield"
    "gpio_stepper_rail"
    "-t"
    "flash"
  ])
  (mkWestBuildBoardCommand "xiao_ble" "" [
    "--shield"
    "gpio_stepper_rail"
  ])
  (mkWestBuildBoardCommand "xiao_ble" "-and-flash" [
    "--shield"
    "gpio_stepper_rail"
    "-t"
    "flash"
  ])
  (mkWestBuildBoardCommand "nrf54l15dk/nrf54l15/cpuapp" "" [ ])
  (mkWestBuildBoardCommand "nrf54l15dk/nrf54l15/cpuapp" "-and-flash" [
    "-t"
    "flash"
  ])
  (mkWestBuildBoardCommand "raytac_an7002q_db/nrf5340/cpuapp" "" [ ])
  (mkWestBuildBoardCommand "raytac_an7002q_db/nrf5340/cpuapp" "-and-flash" [
    "-t"
    "flash"
  ])
  (mkWestBuildBoardCommand "native_sim" "" [ ])
  (pkgs.writeShellScriptBin "west-native_sim-build-and-run" ''
    set -euo pipefail
    set -x
    west-native_sim-build "$@"
    ./builds/native_sim/zephyr/zephyr.exe
  '')
  (mkWestBuildBoardCommand "xiao_esp32s3/esp32s3/procpu" "" [
    "--shield"
    "gpio_stepper_rail"
  ])
  (mkWestBuildBoardCommand "xiao_esp32s3/esp32s3/procpu" "-and-flash" [
    "--shield"
    "gpio_stepper_rail"
    "-t"
    "flash"
  ])
  (mkWestBuildBoardCommand "xiao_esp32c6/esp32c6/hpcore" "" [
    "--shield"
    "gpio_stepper_rail"
  ])
  (mkWestBuildBoardCommand "xiao_esp32c6/esp32c6/hpcore" "-and-flash" [
    "--shield"
    "gpio_stepper_rail"
    "-t"
    "flash"
  ])
  (mkWestCommand "espressif-monitor" [
    "espressif"
    "monitor"
  ])
]
