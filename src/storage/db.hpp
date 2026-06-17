#pragma once

#include <stdexcept>
#include <string>
#include <utility>

#include <sqlite3.h>

namespace urmom::storage::AuthUserRepository {

template <typename Fn>
auto UserDetailsByUsername(const std::string& database_path,
                           const std::string& username,
                           Fn&& callback) {
  sqlite3* db = nullptr;
  if (sqlite3_open_v2(database_path.c_str(), &db, SQLITE_OPEN_READONLY,
                      nullptr) != SQLITE_OK) {
    const std::string message =
        db != nullptr ? sqlite3_errmsg(db) : "failed to open database";
    if (db != nullptr) {
      sqlite3_close(db);
    }
    throw std::runtime_error(message);
  }

  const char* sql =
      "SELECT auth_user.is_active, dash_binding.appname "
      "FROM auth_user "
      "LEFT JOIN dash_binding ON dash_binding.username = auth_user.username "
      "WHERE auth_user.username = ? "
      "ORDER BY dash_binding.appname";

  sqlite3_stmt* stmt = nullptr;
  if (sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr) != SQLITE_OK) {
    const std::string message = sqlite3_errmsg(db);
    sqlite3_close(db);
    throw std::runtime_error(message);
  }

  sqlite3_bind_text(stmt, 1, username.c_str(), -1, SQLITE_TRANSIENT);

  auto result = std::forward<Fn>(callback)(stmt);

  sqlite3_finalize(stmt);
  sqlite3_close(db);
  return result;
}

}  // namespace urmom::storage::AuthUserRepository
