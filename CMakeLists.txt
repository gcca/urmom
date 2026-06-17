cmake_minimum_required(VERSION 4.1)

project(urmom LANGUAGES C CXX)

set(CMAKE_CXX_COMPILER clang++ CACHE FILEPATH "C++ compiler" FORCE)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(gRPC CONFIG REQUIRED)
find_package(Protobuf CONFIG REQUIRED)
find_package(SQLite3 REQUIRED)

include(cmake/ProtoGen.cmake)
include(cmake/ClientGen.cmake)
include(cmake/Argon2.cmake)

add_grpc_proto_library(urmom_proto "${CMAKE_CURRENT_SOURCE_DIR}/protos")
add_proto_client_codegen(gen_client_c LANGUAGE C)
add_proto_client_codegen(gen_client_cpp LANGUAGE CXX)
add_proto_client_codegen(gen_client_go LANGUAGE GO)
add_proto_client_codegen(gen_client_python LANGUAGE PYTHON)
add_proto_client_codegen(gen_client_zig LANGUAGE ZIG)
add_custom_target(gen_clients
  DEPENDS gen_client_c gen_client_cpp gen_client_go gen_client_python gen_client_zig
)

add_executable(urmom
  src/urmom.cc
  src/urmom/services/auth/authenticate.cpp
  src/urmom/services/auth/user_details.cpp
)

target_include_directories(urmom SYSTEM PRIVATE 3rdparty ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(urmom PRIVATE src)

target_link_libraries(urmom PRIVATE
  argon2::argon2
  gRPC::grpc++
  SQLite3::SQLite3
  urmom_proto
)

option(URMOM_TESTS "Build and enable tests" OFF)

if(URMOM_TESTS)
  find_package(GTest REQUIRED)
  enable_testing()

  add_executable(urmom-auth-test
    src/urmom/services/auth-test.cc
    src/urmom/services/auth/authenticate.cpp
    src/urmom/services/auth/user_details.cpp
  )
  target_compile_features(urmom-auth-test PRIVATE cxx_std_23)
  target_include_directories(urmom-auth-test SYSTEM PRIVATE
    3rdparty
    ${CMAKE_CURRENT_BINARY_DIR}
  )
  target_include_directories(urmom-auth-test PRIVATE src)
  target_link_libraries(urmom-auth-test PRIVATE
    GTest::gtest_main
    GTest::gmock
    argon2::argon2
    gRPC::grpc++
    SQLite3::SQLite3
    urmom_proto
  )
  add_test(NAME urmom-auth-test COMMAND urmom-auth-test)
endif()
