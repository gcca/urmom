function(add_grpc_proto_library TARGET PROTO_DIR)
  file(GLOB PROTO_FILES "${PROTO_DIR}/*.proto")

  set(GEN_SRCS)
  foreach(PROTO_FILE ${PROTO_FILES})
    get_filename_component(NAME ${PROTO_FILE} NAME_WE)

    set(PB_H    "${CMAKE_CURRENT_BINARY_DIR}/${NAME}.pb.h")
    set(PB_CC   "${CMAKE_CURRENT_BINARY_DIR}/${NAME}.pb.cc")
    set(GRPC_H  "${CMAKE_CURRENT_BINARY_DIR}/${NAME}.grpc.pb.h")
    set(GRPC_CC "${CMAKE_CURRENT_BINARY_DIR}/${NAME}.grpc.pb.cc")

    add_custom_command(
      OUTPUT ${PB_H} ${PB_CC} ${GRPC_H} ${GRPC_CC}
      COMMAND $<TARGET_FILE:protobuf::protoc>
              --cpp_out=${CMAKE_CURRENT_BINARY_DIR}
              --grpc_out=${CMAKE_CURRENT_BINARY_DIR}
              --plugin=protoc-gen-grpc=$<TARGET_FILE:gRPC::grpc_cpp_plugin>
              -I ${PROTO_DIR}
              ${PROTO_FILE}
      DEPENDS ${PROTO_FILE}
      COMMENT "Generating gRPC/Protobuf C++ for ${NAME}.proto"
      VERBATIM
    )

    list(APPEND GEN_SRCS ${PB_CC} ${GRPC_CC})
  endforeach()

  add_library(${TARGET} STATIC ${GEN_SRCS})
  target_link_libraries(${TARGET} PUBLIC protobuf::libprotobuf gRPC::grpc++)
  target_include_directories(${TARGET} PUBLIC "${CMAKE_CURRENT_BINARY_DIR}")
endfunction()
