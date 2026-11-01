cmake_minimum_required(VERSION 3.20)
project(ets2carplay_telemetry LANGUAGES CXX)

add_library(ets2carplay_telemetry SHARED SCSPlugin.cpp telemetry.def)
target_include_directories(ets2carplay_telemetry PRIVATE ../SCS_SDK/include)
target_compile_features(ets2carplay_telemetry PRIVATE cxx_std_17)
target_compile_definitions(ets2carplay_telemetry PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(ets2carplay_telemetry PRIVATE ws2_32)
set_target_properties(ets2carplay_telemetry PROPERTIES PREFIX "" SUFFIX ".dll")
