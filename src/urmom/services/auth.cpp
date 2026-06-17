#include "urmom/services/auth.hpp"

#include "storage/db.hpp"

namespace urmom::services {

AuthServiceImpl::AuthServiceImpl(std::string database_path)
    : database_path_(std::move(database_path)) {}

grpc::Status AuthServiceImpl::UserDetails(
    grpc::ServerContext* /*context*/,
    const auth::UserDetailsRequest* request,
    auth::UserDetailsResponse* response) {
  try {
    return urmom::storage::AuthUserRepository::UserDetailsByUsername(
        database_path_, request->username(),
        [&](sqlite3_stmt* stmt) -> grpc::Status {
          int step = sqlite3_step(stmt);
          if (step == SQLITE_DONE) {
            return {grpc::StatusCode::NOT_FOUND, "user not found"};
          }
          if (step != SQLITE_ROW) {
            return {grpc::StatusCode::INTERNAL,
                    sqlite3_errmsg(sqlite3_db_handle(stmt))};
          }

          response->set_is_active(sqlite3_column_int(stmt, 0) != 0);

          while (step == SQLITE_ROW) {
            if (sqlite3_column_type(stmt, 1) != SQLITE_NULL) {
              const char* appname = reinterpret_cast<const char*>(
                  sqlite3_column_text(stmt, 1));
              response->add_apps(appname);
            }

            step = sqlite3_step(stmt);
          }

          if (step != SQLITE_DONE) {
            return {grpc::StatusCode::INTERNAL,
                    sqlite3_errmsg(sqlite3_db_handle(stmt))};
          }

          return grpc::Status::OK;
        });
  } catch (const std::runtime_error& error) {
    return {grpc::StatusCode::INTERNAL, error.what()};
  }
}

}  // namespace urmom::services
