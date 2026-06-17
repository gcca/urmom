#include <limits>
#include <print>
#include <string>

#include "urmom/services/auth.hpp"
#include "urmom/storage/db.hpp"

namespace {

grpc::Status ReadUserInfo(sqlite3* db,
                          const std::string& username,
                          urmom::v1::UserInfo* userinfo) {
  static constexpr char kSql[] = R"sql(
    SELECT auth_user.is_active, dash_binding.appname
      FROM auth_user
      LEFT JOIN dash_binding
        ON dash_binding.username = auth_user.username
     WHERE auth_user.username = ?
     ORDER BY dash_binding.appname
  )sql";

  sqlite3_stmt* stmt = nullptr;
  if (sqlite3_prepare_v2(db, kSql, -1, &stmt, nullptr) != SQLITE_OK) {
    const std::string message = sqlite3_errmsg(db);
    std::println("ERROR: prepare statement on UserInfo: {}", message);
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
    std::println("ERROR: bind username on UserInfo: {}", message);
    sqlite3_finalize(stmt);
    return {grpc::StatusCode::INTERNAL, message};
  }

  int step = sqlite3_step(stmt);
  if (step == SQLITE_DONE) {
    sqlite3_finalize(stmt);
    return {grpc::StatusCode::NOT_FOUND, "user not found"};
  }

  if (step != SQLITE_ROW) {
    const std::string message = sqlite3_errmsg(db);
    std::println("ERROR: read user on UserInfo: {}", message);
    sqlite3_finalize(stmt);
    return {grpc::StatusCode::INTERNAL, message};
  }

  userinfo->set_is_active(sqlite3_column_int(stmt, 0) != 0);

  while (step == SQLITE_ROW) {
    const auto* appname =
        reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
    if (appname != nullptr) {
      userinfo->add_apps(appname, sqlite3_column_bytes(stmt, 1));
    }

    step = sqlite3_step(stmt);
  }

  if (step != SQLITE_DONE) {
    const std::string message = sqlite3_errmsg(db);
    std::println("ERROR: read apps on UserInfo: {}", message);
    sqlite3_finalize(stmt);
    return {grpc::StatusCode::INTERNAL, message};
  }

  sqlite3_finalize(stmt);
  return grpc::Status::OK;
}

}  // namespace

namespace urmom::services {

grpc::Status AuthServiceImpl::LoadUserInfo(const std::string& username,
                                           v1::UserInfo* userinfo) const {
  sqlite3* db = nullptr;
  if (storage::Sqlite3OpenRO(db, dbname_)) {
    std::println("ERROR: db not found on UserInfo");
    return {grpc::StatusCode::INTERNAL, "db not found"};
  }

  const grpc::Status status = ReadUserInfo(db, username, userinfo);
  sqlite3_close(db);
  return status;
}

grpc::Status AuthServiceImpl::UserInfo(grpc::ServerContext*,
                                       const v1::UserInfoRequest* request,
                                       v1::UserInfoResponse* response) {
  v1::UserInfo userinfo;
  const grpc::Status status = LoadUserInfo(request->username(), &userinfo);
  if (!status.ok()) {
    return status;
  }

  response->mutable_userinfo()->Swap(&userinfo);
  return grpc::Status::OK;
}

}  // namespace urmom::services
