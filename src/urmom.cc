#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <string>

#include <CLI11.hpp>
#include <grpcpp/grpcpp.h>

#include "urmom/services/auth.hpp"

namespace {

std::string ServerAddress(std::uint16_t port) {
  return "0.0.0.0:" + std::to_string(port);
}

static void SetCLIArgs(CLI::App& app,
                       std::uint16_t& port,
                       std::string& database_path) {
  port = 50051;
  database_path = "data/urmom.db";
  app.add_option("-p,--port", port, "Port to listen on")
      ->check(CLI::Range(1, 65535))
      ->capture_default_str();
  app.add_option("-d,--database", database_path, "SQLite database path")
      ->capture_default_str();
}

}  // namespace

int main(int argc, char* argv[]) {
  CLI::App app{"urmom"};
  std::uint16_t port;
  std::string database_path;
  SetCLIArgs(app, port, database_path);

  CLI11_PARSE(app, argc, argv);

  const std::string server_address = ServerAddress(port);

  grpc::EnableDefaultHealthCheckService(true);

  urmom::services::AuthServiceImpl auth_service{database_path};

  grpc::ServerBuilder builder;
  builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
  builder.RegisterService(&auth_service);

  std::unique_ptr<grpc::Server> server(builder.BuildAndStart());
  if (server == nullptr) {
    std::cerr << "Failed to start urmom on " << server_address << '\n';
    return EXIT_FAILURE;
  }

  grpc::HealthCheckServiceInterface* health_service =
      server->GetHealthCheckService();
  if (health_service != nullptr) {
    health_service->SetServingStatus(true);
  }

  std::cout << "urmom listening on " << server_address << '\n';
  server->Wait();

  return EXIT_SUCCESS;
}
