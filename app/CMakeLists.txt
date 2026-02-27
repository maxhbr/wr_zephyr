# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

set(CMAKE_C_FLAGS -lstdc++)
set(CMAKE_CXX_FLAGS -lstdc++)

set(BOARD xiao_nrf54l15/nrf54l15/cpuapp)

# Add DTS bindings path BEFORE find_package(Zephyr)
list(APPEND DTS_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../lib/stepper_with_target)
list(APPEND DTS_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/boards)

# Add shield root BEFORE find_package(Zephyr)
list(APPEND BOARD_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# Capture Git commit hash before find_package
execute_process(
  COMMAND git rev-parse --short HEAD
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  OUTPUT_VARIABLE GIT_COMMIT_HASH
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_QUIET
)
if(NOT GIT_COMMIT_HASH)
  set(GIT_COMMIT_HASH "unknown")
else()
    # Optionally detect if the working tree is dirty
    execute_process(
        COMMAND git diff --quiet --ignore-submodules HEAD
        RESULT_VARIABLE GIT_DIRTY
    )

    if (GIT_DIRTY EQUAL 1)
        set(GIT_COMMIT_HASH "${GIT_COMMIT_HASH}-dirty")
    endif()
endif()

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(zephyr-rail)

# Define BUILD_COMMIT as a string macro
add_compile_definitions(BUILD_COMMIT="${GIT_COMMIT_HASH}")

zephyr_library_compile_options(-lstdc++ -std=c++17 -fpermissive)

# Add the sony_remote library
add_subdirectory(../lib/sony_remote ${CMAKE_CURRENT_BINARY_DIR}/sony_remote)

# Add stepper_with_target library (includes the driver)
add_subdirectory(../lib/stepper_with_target ${CMAKE_CURRENT_BINARY_DIR}/stepper_with_target)

FILE(GLOB app_sources src/*.cpp)

if(NOT CONFIG_BT)
    list(FILTER app_sources EXCLUDE REGEX "pwa_service\\.cpp$")
    list(FILTER app_sources EXCLUDE REGEX "bluetooth\\.cpp$")
endif()

target_sources(app PRIVATE ${app_sources})

# Link the libraries
target_link_libraries(app PRIVATE sony_remote stepper_with_target)
