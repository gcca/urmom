cmake_minimum_required(VERSION 3.16)

project(urmom LANGUAGES CXX)

find_package(gRPC CONFIG REQUIRED)
find_package(Protobuf CONFIG REQUIRED)
find_package(SQLite3 REQUIRED)

include(cmake/ProtoGen.cmake)
include(cmake/ClientGen.cmake)

add_grpc_proto_library(urmom_proto "${CMAKE_CURRENT_SOURCE_DIR}/protos")
add_proto_client_codegen(gen_client_c LANGUAGE C)
add_proto_client_codegen(gen_client_cpp LANGUAGE CXX)
add_custom_target(gen_clients
  DEPENDS gen_client_c gen_client_cpp
)

add_executable(urmom
  src/urmom.cc
  src/urmom/services/auth.cpp
)

target_include_directories(urmom SYSTEM PRIVATE 3rdparty ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(urmom PRIVATE src)

target_link_libraries(urmom PRIVATE gRPC::grpc++ urmom_proto SQLite3::SQLite3)
