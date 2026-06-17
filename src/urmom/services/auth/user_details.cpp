#include "urmom/services/auth.hpp"
#include "urmom/storage/db.hpp"

using namespace urmom::storage;

namespace {

inline std::optional<grpc::Status> ReadIsActive(
    sqlite3* db,
    const auth::UserDetailsRequest* request,
    auth::UserDetailsResponse* response) {
  const char* sql = "SELECT is_active FROM auth_user WHERE username = ?";

  sqlite3_stmt* stmt = nullptr;
  if (Sqlite3Prepare(db, stmt, sql)) {
    std::println("ERROR: prepare stmt on UserDetails ReadIsActive");
    return grpc::Status{grpc::StatusCode::INTERNAL,
                        "failed is_active prepare stmt"};
  }

  auto username = request->username();

  if (Sqlite3BindText(db, stmt, 1, username.data(), username.length())) {
    std::println("ERROR: bind text username on UserDetails ReadIsActive");
    return grpc::Status{grpc::StatusCode::INTERNAL,
                        "failed is_active bind text username"};
  }

  int step = sqlite3_step(stmt);

  if (step == SQLITE_DONE) {
    std::println("ERROR: is_active user not found");
    sqlite3_finalize(stmt);
    return grpc::Status{grpc::StatusCode::NOT_FOUND,
                        "is_active user not found"};
  }

  if (step != SQLITE_ROW) {
    const std::string msg = sqlite3_errmsg(db);
    std::println("ERROR: step != SQLITE_ROW on UserDetails ReadIsActive: {}",
                 msg);
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return grpc::Status{grpc::StatusCode::INTERNAL, msg};
  }

  const bool is_active = sqlite3_column_int(stmt, 0) != 0;

  response->set_is_active(is_active);

  sqlite3_finalize(stmt);

  return std::nullopt;
}

inline std::optional<grpc::Status> ReadApps(
    sqlite3* db,
    const auth::UserDetailsRequest* request,
    auth::UserDetailsResponse* response) {
  const char* sql = "SELECT appname FROM dash_binding WHERE username = ?";

  sqlite3_stmt* stmt = nullptr;
  if (Sqlite3Prepare(db, stmt, sql)) {
    std::println("ERROR: prepare stmt on UserDetails ReadApps");
    return grpc::Status{grpc::StatusCode::INTERNAL, "failed apps prepare stmt"};
  }

  auto username = request->username();

  if (Sqlite3BindText(db, stmt, 1, username.data(), username.length())) {
    std::println("ERROR: bind text username on UserDetails ReadApps");
    return grpc::Status{grpc::StatusCode::INTERNAL,
                        "failed apps bind text username"};
  }

  int step = sqlite3_step(stmt);

  while (step == SQLITE_ROW) {
    auto appname = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));

    if (appname != nullptr) {
      std::println("null appname found");
      response->add_apps(appname);
    }

    step = sqlite3_step(stmt);
  }

  if (step != SQLITE_DONE) {
    const std::string msg = sqlite3_errmsg(db);
    std::println("ERROR: step != SQLITE_DONE on UserDetails ReadApps: {}", msg);
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return grpc::Status{grpc::StatusCode::INTERNAL, msg};
  }

  sqlite3_finalize(stmt);

  return std::nullopt;
}

}  // namespace

namespace urmom::services {

grpc::Status AuthServiceImpl::UserDetails(
    grpc::ServerContext*,
    const auth::UserDetailsRequest* request,
    auth::UserDetailsResponse* response) {
  sqlite3* db = nullptr;

  if (Sqlite3OpenRO(db, dbname_)) {
    std::println("ERROR: db not found on UserDetails");
    return {grpc::StatusCode::INTERNAL, "db not found"};
  }

  if (auto opt = ReadIsActive(db, request, response)) {
    sqlite3_close(db);
    return *opt;
  }

  if (auto opt = ReadApps(db, request, response)) {
    sqlite3_close(db);
    return *opt;
  }

  return grpc::Status::OK;
}

}  // namespace urmom::services
