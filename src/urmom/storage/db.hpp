#pragma once

#include <print>
#include <string>

#include <sqlite3.h>

namespace urmom::storage {

[[nodiscard]] static inline __attribute__((always_inline)) bool Sqlite3OpenRO(
    sqlite3*& db,
    const std::string& dbname) {
  if (sqlite3_open_v2(dbname.c_str(), &db, SQLITE_OPEN_READONLY, nullptr) !=
      SQLITE_OK) {
    if (db) {
      const std::string msg = sqlite3_errmsg(db);
      sqlite3_close(db);
      std::println("failed open db: {}", msg);
    } else {
      std::println("failed open db");
    }
    return true;
  }
  return false;
}

[[nodiscard]] static inline __attribute__((always_inline)) bool
Sqlite3Prepare(sqlite3* db, sqlite3_stmt*& stmt, const char* sql) {
  if (sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr) != SQLITE_OK) {
    const std::string msg = sqlite3_errmsg(db);
    sqlite3_close(db);
    std::println("failed prepare stmt: {}", msg);
    return true;
  }
  return false;
}

[[nodiscard]] static inline __attribute__((always_inline)) bool Sqlite3BindText(
    sqlite3* db,
    sqlite3_stmt* stmt,
    int p,
    const char* data,
    int len) {
  if (sqlite3_bind_text(stmt, 1, data, -1, SQLITE_TRANSIENT) != SQLITE_OK) {
    const std::string msg = sqlite3_errmsg(db);
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    std::println("failed bind text: {}", msg);
    return true;
  }
  return false;
}

}  // namespace urmom::storage
