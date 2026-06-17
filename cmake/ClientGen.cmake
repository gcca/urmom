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
  else()
    message(FATAL_ERROR "Unsupported client protobuf language: ${ARG_LANGUAGE}")
  endif()

  add_custom_target(${TARGET} DEPENDS ${GEN_FILES})
endfunction()
