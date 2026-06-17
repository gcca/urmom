#include <argon2.h>

#include "urmom/services/auth.hpp"
#include "urmom/storage/db.hpp"

using namespace urmom::storage;

namespace {

inline std::optional<grpc::Status> ReadPassword(
    sqlite3* db,
    const auth::AuthenticateRequest* request,
    std::string& password) {
  const char* sql = "SELECT password FROM auth_user WHERE username = ?";

  sqlite3_stmt* stmt;
  if (Sqlite3Prepare(db, stmt, sql)) {
    std::println("ERROR: prepare stmt on Authenticate ReadPassword");
    return grpc::Status{grpc::StatusCode::INTERNAL,
                        "failed password prepare stmt"};
  }

  auto username = request->username();

  if (Sqlite3BindText(db, stmt, 1, username.data(), username.length())) {
    std::println("ERROR: bind text username on Authenticate ReadPassword");
    return grpc::Status{grpc::StatusCode::INTERNAL,
                        "faile password bind text username"};
  }

  int step = sqlite3_step(stmt);

  if (step == SQLITE_DONE) {
    std::println("ERROR: not found on read password: username");
    sqlite3_finalize(stmt);
    return grpc::Status{grpc::StatusCode::NOT_FOUND,
                        "not found on read password: username"};
  }

  if (step != SQLITE_ROW) {
    const std::string msg = sqlite3_errmsg(db);
    std::println("ERROR: step != SQLITE_ROW on Authenticate ReadPassword: {}",
                 msg);
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return grpc::Status{grpc::StatusCode::INTERNAL, msg};
  }

  password = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));

  sqlite3_finalize(stmt);

  return std::nullopt;
}

}  // namespace

namespace urmom::services {

grpc::Status AuthServiceImpl::Authenticate(
    grpc::ServerContext*,
    const auth::AuthenticateRequest* request,
    auth::AuthenticateResponse* response) {
  sqlite3* db = nullptr;

  if (Sqlite3OpenRO(db, dbname_)) {
    std::println("ERROR: db not found on Authenticate");
    return grpc::Status{grpc::StatusCode::INTERNAL, "db not found"};
  }

  std::string stored_password;
  if (auto status = ReadPassword(db, request, stored_password)) {
    sqlite3_close(db);
    return *status;
  }

  sqlite3_close(db);

  const std::string request_password =
      request->password() + request->username();

  const int verify =
      argon2d_verify(stored_password.c_str(), request_password.data(),
                     request_password.size());

  if (verify == ARGON2_OK) {
    response->set_authenticated(true);
    return grpc::Status::OK;
  }

  response->set_authenticated(false);
  return grpc::Status{grpc::StatusCode::UNAUTHENTICATED, "invalid password"};
}

}  // namespace urmom::services
