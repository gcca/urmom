#include <limits>
#include <print>
#include <string>

#include <argon2.h>

#include "urmom/services/auth.hpp"
#include "urmom/storage/db.hpp"

namespace {

grpc::Status ReadPassword(sqlite3* db,
                          const std::string& username,
                          std::string& password) {
  static constexpr char kSql[] =
      "SELECT password FROM auth_user WHERE username = ?";

  sqlite3_stmt* stmt = nullptr;
  if (sqlite3_prepare_v2(db, kSql, -1, &stmt, nullptr) != SQLITE_OK) {
    const std::string message = sqlite3_errmsg(db);
    std::println("ERROR: prepare statement on Authenticate: {}", message);
    if (stmt != nullptr) {
      sqlite3_finalize(stmt);
    }
    return {grpc::StatusCode::INTERNAL, message};
  }

  if (username.size() >
      static_cast<std::size_t>(std::numeric_limits<int>::max())) {
    sqlite3_finalize(stmt);
    return {grpc::StatusCode::INVALID_ARGUMENT, "username is too long"};
  }

  if (sqlite3_bind_text(stmt, 1, username.data(),
                        static_cast<int>(username.size()),
                        SQLITE_TRANSIENT) != SQLITE_OK) {
    const std::string message = sqlite3_errmsg(db);
    std::println("ERROR: bind username on Authenticate: {}", message);
    sqlite3_finalize(stmt);
    return {grpc::StatusCode::INTERNAL, message};
  }

  const int step = sqlite3_step(stmt);
  if (step == SQLITE_DONE) {
    sqlite3_finalize(stmt);
    return {grpc::StatusCode::NOT_FOUND, "user not found"};
  }

  if (step != SQLITE_ROW) {
    const std::string message = sqlite3_errmsg(db);
    std::println("ERROR: read password on Authenticate: {}", message);
    sqlite3_finalize(stmt);
    return {grpc::StatusCode::INTERNAL, message};
  }

  const auto* stored_password =
      reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
  if (stored_password == nullptr) {
    sqlite3_finalize(stmt);
    return {grpc::StatusCode::INTERNAL, "stored password is null"};
  }

  password.assign(stored_password, sqlite3_column_bytes(stmt, 0));
  sqlite3_finalize(stmt);
  return grpc::Status::OK;
}

}  // namespace

namespace urmom::services {

grpc::Status AuthServiceImpl::Authenticate(
    grpc::ServerContext*,
    const v1::AuthenticateRequest* request,
    v1::AuthenticateResponse* response) {
  sqlite3* db = nullptr;
  if (storage::Sqlite3OpenRO(db, dbname_)) {
    std::println("ERROR: db not found on Authenticate");
    return {grpc::StatusCode::INTERNAL, "db not found"};
  }

  std::string stored_password;
  const grpc::Status read_status =
      ReadPassword(db, request->username(), stored_password);
  sqlite3_close(db);
  if (!read_status.ok()) {
    return read_status;
  }

  const std::string request_password =
      request->password() + request->username();
  const int verify =
      argon2d_verify(stored_password.c_str(), request_password.data(),
                     request_password.size());

  if (verify != ARGON2_OK) {
    response->set_authenticated(false);
    response->clear_userinfo();
    return {grpc::StatusCode::UNAUTHENTICATED, "invalid password"};
  }

  v1::UserInfo userinfo;
  const grpc::Status info_status = LoadUserInfo(request->username(), &userinfo);
  if (!info_status.ok()) {
    return info_status;
  }

  response->set_authenticated(true);
  response->mutable_userinfo()->Swap(&userinfo);
  return grpc::Status::OK;
}

}  // namespace urmom::services
