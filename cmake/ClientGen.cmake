function(add_proto_client_codegen TARGET)
  set(options GRPC)
  set(one_value_args LANGUAGE PROTO_DIR OUTPUT_DIR)
  cmake_parse_arguments(ARG "${options}" "${one_value_args}" "" ${ARGN})

  if(NOT ARG_LANGUAGE)
    message(FATAL_ERROR "add_proto_client_codegen(${TARGET}) requires LANGUAGE")
  endif()
  string(TOLOWER "${ARG_LANGUAGE}" LANGUAGE)
  if(LANGUAGE STREQUAL "cxx")
    set(OUTPUT_LANGUAGE "cpp")
  else()
    set(OUTPUT_LANGUAGE "${LANGUAGE}")
  endif()

  if(NOT ARG_PROTO_DIR)
    set(ARG_PROTO_DIR "${CMAKE_CURRENT_SOURCE_DIR}/protos")
  endif()
  if(NOT ARG_OUTPUT_DIR)
    set(ARG_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/clients/${OUTPUT_LANGUAGE}")
  endif()

  file(GLOB PROTO_FILES CONFIGURE_DEPENDS "${ARG_PROTO_DIR}/*.proto")
  if(NOT PROTO_FILES)
    message(FATAL_ERROR "No .proto files found in ${ARG_PROTO_DIR}")
  endif()

  set(GEN_FILES)

  if(LANGUAGE STREQUAL "c")
    find_program(PROTOC_GEN_C protoc-gen-c)
    if(PROTOC_GEN_C)
      set(PROTOC_GEN_C_ARG --plugin=protoc-gen-c=${PROTOC_GEN_C})
    else()
      set(PROTOC_GEN_C_ARG)
      message(STATUS
        "protoc-gen-c not found; target ${TARGET} requires protobuf-c on PATH")
    endif()

    foreach(PROTO_FILE ${PROTO_FILES})
      get_filename_component(NAME ${PROTO_FILE} NAME_WE)

      set(PB_C_H "${ARG_OUTPUT_DIR}/${NAME}.pb-c.h")
      set(PB_C_C "${ARG_OUTPUT_DIR}/${NAME}.pb-c.c")

      add_custom_command(
        OUTPUT ${PB_C_H} ${PB_C_C}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${ARG_OUTPUT_DIR}
        COMMAND $<TARGET_FILE:protobuf::protoc>
                ${PROTOC_GEN_C_ARG}
                --c_out=${ARG_OUTPUT_DIR}
                -I ${ARG_PROTO_DIR}
                ${PROTO_FILE}
        DEPENDS ${PROTO_FILE}
        COMMENT "Generating protobuf-c client code for ${NAME}.proto"
        VERBATIM
      )

      list(APPEND GEN_FILES ${PB_C_H} ${PB_C_C})
    endforeach()
  elseif(LANGUAGE STREQUAL "cpp" OR LANGUAGE STREQUAL "cxx")
    foreach(PROTO_FILE ${PROTO_FILES})
      get_filename_component(NAME ${PROTO_FILE} NAME_WE)

      set(PB_H    "${ARG_OUTPUT_DIR}/${NAME}.pb.h")
      set(PB_CC   "${ARG_OUTPUT_DIR}/${NAME}.pb.cc")
      set(GRPC_H  "${ARG_OUTPUT_DIR}/${NAME}.grpc.pb.h")
      set(GRPC_CC "${ARG_OUTPUT_DIR}/${NAME}.grpc.pb.cc")

      add_custom_command(
        OUTPUT ${PB_H} ${PB_CC} ${GRPC_H} ${GRPC_CC}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${ARG_OUTPUT_DIR}
        COMMAND $<TARGET_FILE:protobuf::protoc>
                --cpp_out=${ARG_OUTPUT_DIR}
                --grpc_out=${ARG_OUTPUT_DIR}
                --plugin=protoc-gen-grpc=$<TARGET_FILE:gRPC::grpc_cpp_plugin>
                -I ${ARG_PROTO_DIR}
                ${PROTO_FILE}
        DEPENDS ${PROTO_FILE}
        COMMENT "Generating gRPC/Protobuf C++ client code for ${NAME}.proto"
        VERBATIM
      )

      list(APPEND GEN_FILES ${PB_H} ${PB_CC} ${GRPC_H} ${GRPC_CC})
    endforeach()
  elseif(LANGUAGE STREQUAL "go")
    find_program(PROTOC_GEN_GO protoc-gen-go)
    if(PROTOC_GEN_GO)
      set(PROTOC_GEN_GO_ARG --plugin=protoc-gen-go=${PROTOC_GEN_GO})
    else()
      set(PROTOC_GEN_GO_ARG)
      message(STATUS
        "protoc-gen-go not found; target ${TARGET} requires protoc-gen-go on PATH")
    endif()

    find_program(PROTOC_GEN_GO_GRPC protoc-gen-go-grpc)
    if(PROTOC_GEN_GO_GRPC)
      set(PROTOC_GEN_GO_GRPC_ARG --plugin=protoc-gen-go-grpc=${PROTOC_GEN_GO_GRPC})
    else()
      set(PROTOC_GEN_GO_GRPC_ARG)
      message(STATUS
        "protoc-gen-go-grpc not found; target ${TARGET} requires protoc-gen-go-grpc on PATH")
    endif()

    foreach(PROTO_FILE ${PROTO_FILES})
      get_filename_component(NAME ${PROTO_FILE} NAME_WE)

      set(PB_GO "${ARG_OUTPUT_DIR}/${NAME}.pb.go")
      set(GRPC_GO "${ARG_OUTPUT_DIR}/${NAME}_grpc.pb.go")

      add_custom_command(
        OUTPUT ${PB_GO} ${GRPC_GO}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${ARG_OUTPUT_DIR}
        COMMAND $<TARGET_FILE:protobuf::protoc>
                ${PROTOC_GEN_GO_ARG}
                ${PROTOC_GEN_GO_GRPC_ARG}
                --go_out=${ARG_OUTPUT_DIR}
                --go_opt=paths=source_relative
                --go-grpc_out=${ARG_OUTPUT_DIR}
                --go-grpc_opt=paths=source_relative
                -I ${ARG_PROTO_DIR}
                ${PROTO_FILE}
        DEPENDS ${PROTO_FILE}
        COMMENT "Generating gRPC/Protobuf Go client code for ${NAME}.proto"
        VERBATIM
      )

      list(APPEND GEN_FILES ${PB_GO} ${GRPC_GO})
    endforeach()
  elseif(LANGUAGE STREQUAL "python")
    find_package(Python3 QUIET COMPONENTS Interpreter)
    if(Python3_FOUND)
      set(PYTHON_GRPC_TOOLS_COMMAND ${Python3_EXECUTABLE})
      execute_process(
        COMMAND ${Python3_EXECUTABLE} -c "import grpc_tools.protoc"
        RESULT_VARIABLE PYTHON_GRPC_TOOLS_RESULT
        OUTPUT_QUIET
        ERROR_QUIET
      )
      if(NOT PYTHON_GRPC_TOOLS_RESULT EQUAL 0)
        message(STATUS
          "grpcio-tools not found; target ${TARGET} requires python3 -m grpc_tools.protoc")
      endif()
    else()
      set(PYTHON_GRPC_TOOLS_COMMAND python3)
      message(STATUS
        "Python3 interpreter not found; target ${TARGET} requires python3 and grpcio-tools on PATH")
    endif()

    foreach(PROTO_FILE ${PROTO_FILES})
      get_filename_component(NAME ${PROTO_FILE} NAME_WE)

      set(PB_PY "${ARG_OUTPUT_DIR}/${NAME}_pb2.py")
      set(GRPC_PY "${ARG_OUTPUT_DIR}/${NAME}_pb2_grpc.py")

      add_custom_command(
        OUTPUT ${PB_PY} ${GRPC_PY}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${ARG_OUTPUT_DIR}
        COMMAND ${PYTHON_GRPC_TOOLS_COMMAND}
                -m grpc_tools.protoc
                --python_out=${ARG_OUTPUT_DIR}
                --grpc_python_out=${ARG_OUTPUT_DIR}
                -I ${ARG_PROTO_DIR}
                ${PROTO_FILE}
        DEPENDS ${PROTO_FILE}
        COMMENT "Generating gRPC/Protobuf Python client code for ${NAME}.proto"
        VERBATIM
      )

      list(APPEND GEN_FILES ${PB_PY} ${GRPC_PY})
    endforeach()
  elseif(LANGUAGE STREQUAL "zig")
    find_program(PROTOC_GEN_ZIG protoc-gen-zig)
    if(PROTOC_GEN_ZIG)
      set(PROTOC_GEN_ZIG_ARG --plugin=protoc-gen-zig=${PROTOC_GEN_ZIG})
    else()
      set(PROTOC_GEN_ZIG_ARG)
      message(STATUS
        "protoc-gen-zig not found; target ${TARGET} requires protoc-gen-zig on PATH")
    endif()

    foreach(PROTO_FILE ${PROTO_FILES})
      get_filename_component(NAME ${PROTO_FILE} NAME_WE)

      set(PB_ZIG "${ARG_OUTPUT_DIR}/${NAME}.pb.zig")

      add_custom_command(
        OUTPUT ${PB_ZIG}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${ARG_OUTPUT_DIR}
        COMMAND $<TARGET_FILE:protobuf::protoc>
                ${PROTOC_GEN_ZIG_ARG}
                --zig_out=${ARG_OUTPUT_DIR}
                -I ${ARG_PROTO_DIR}
                ${PROTO_FILE}
        DEPENDS ${PROTO_FILE}
        COMMENT "Generating Zig protobuf client code for ${NAME}.proto"
        VERBATIM
      )

      list(APPEND GEN_FILES ${PB_ZIG})
    endforeach()
  else()
    message(FATAL_ERROR "Unsupported client protobuf language: ${ARG_LANGUAGE}")
  endif()

  add_custom_target(${TARGET} DEPENDS ${GEN_FILES})
endfunction()
