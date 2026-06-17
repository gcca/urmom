#include "urmom/services/auth.hpp"

#include <array>
#include <cstdint>
#include <filesystem>
#include <memory>
#include <random>
#include <stdexcept>
#include <string>
#include <system_error>
#include <vector>

#include <argon2.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>
#include <sqlite3.h>

namespace {

using ::testing::ElementsAre;
using urmom::services::AuthServiceImpl;

std::string PasswordHash(const std::string& username,
                         const std::string& password) {
  static constexpr std::uint32_t kTimeCost = 1;
  static constexpr std::uint32_t kMemoryCost = 32;
  static constexpr std::uint32_t kParallelism = 1;
  static constexpr std::uint32_t kHashLength = 32;
  static constexpr std::array<unsigned char, 16> kSalt = {
      0x75, 0x72, 0x6d, 0x6f, 0x6d, 0x2d, 0x61, 0x75,
      0x74, 0x68, 0x2d, 0x74, 0x65, 0x73, 0x74, 0x73,
  };

  const std::string prepared_password = password + username;
  std::vector<char> encoded(argon2_encodedlen(kTimeCost, kMemoryCost,
                                              kParallelism, kSalt.size(),
                                              kHashLength, Argon2_d));

  const int result = argon2d_hash_encoded(
      kTimeCost, kMemoryCost, kParallelism, prepared_password.data(),
      prepared_password.size(), kSalt.data(), kSalt.size(), kHashLength,
      encoded.data(), encoded.size());
  if (result != ARGON2_OK) {
    throw std::runtime_error(argon2_error_message(result));
  }

  return encoded.data();
}

class AuthServiceTest : public ::testing::Test {
 protected:
  void SetUp() override {
    database_path_ =
        std::filesystem::temp_directory_path() /
        ("urmom-auth-test-" + std::to_string(std::random_device{}()) + ".db");

    ASSERT_EQ(sqlite3_open(database_path_.c_str(), &database_), SQLITE_OK);
    Execute(R"sql(
      PRAGMA foreign_keys = ON;
      CREATE TABLE auth_user (
        username TEXT NOT NULL PRIMARY KEY,
        password TEXT NOT NULL,
        is_active INTEGER NOT NULL
      );
      CREATE TABLE dash_binding (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL REFERENCES auth_user(username),
        appname TEXT NOT NULL,
        UNIQUE (username, appname)
      );
    )sql");

    InsertUser("alice", "correct horse", true);
    InsertUser("bob", "another password", false);
    InsertApp("alice", "zeta");
    InsertApp("alice", "alpha");

    ASSERT_EQ(sqlite3_close(database_), SQLITE_OK);
    database_ = nullptr;
    service_ = std::make_unique<AuthServiceImpl>(database_path_.string());
  }

  void TearDown() override {
    service_.reset();
    if (database_ != nullptr) {
      sqlite3_close(database_);
    }
    std::error_code error;
    std::filesystem::remove(database_path_, error);
  }

  void Execute(const char* sql) {
    char* error = nullptr;
    const int result = sqlite3_exec(database_, sql, nullptr, nullptr, &error);
    if (result != SQLITE_OK) {
      const std::string message =
          error == nullptr ? "unknown sqlite error" : error;
      sqlite3_free(error);
      FAIL() << message;
    }
  }

  void InsertUser(const std::string& username,
                  const std::string& password,
                  bool is_active) {
    sqlite3_stmt* stmt = nullptr;
    ASSERT_EQ(sqlite3_prepare_v2(
                  database_,
                  "INSERT INTO auth_user (username, password, is_active) "
                  "VALUES (?, ?, ?)",
                  -1, &stmt, nullptr),
              SQLITE_OK);

    const std::string password_hash = PasswordHash(username, password);
    ASSERT_EQ(sqlite3_bind_text(stmt, 1, username.data(), username.size(),
                                SQLITE_TRANSIENT),
              SQLITE_OK);
    ASSERT_EQ(sqlite3_bind_text(stmt, 2, password_hash.data(),
                                password_hash.size(), SQLITE_TRANSIENT),
              SQLITE_OK);
    ASSERT_EQ(sqlite3_bind_int(stmt, 3, is_active ? 1 : 0), SQLITE_OK);
    ASSERT_EQ(sqlite3_step(stmt), SQLITE_DONE);
    ASSERT_EQ(sqlite3_finalize(stmt), SQLITE_OK);
  }

  void InsertApp(const std::string& username, const std::string& appname) {
    sqlite3_stmt* stmt = nullptr;
    ASSERT_EQ(sqlite3_prepare_v2(
                  database_,
                  "INSERT INTO dash_binding (username, appname) VALUES (?, ?)",
                  -1, &stmt, nullptr),
              SQLITE_OK);
    ASSERT_EQ(sqlite3_bind_text(stmt, 1, username.data(), username.size(),
                                SQLITE_TRANSIENT),
              SQLITE_OK);
    ASSERT_EQ(sqlite3_bind_text(stmt, 2, appname.data(), appname.size(),
                                SQLITE_TRANSIENT),
              SQLITE_OK);
    ASSERT_EQ(sqlite3_step(stmt), SQLITE_DONE);
    ASSERT_EQ(sqlite3_finalize(stmt), SQLITE_OK);
  }

  grpc::Status UserInfo(const std::string& username) {
    urmom::v1::UserInfoRequest request;
    request.set_username(username);
    user_info_response_.Clear();
    return service_->UserInfo(nullptr, &request, &user_info_response_);
  }

  grpc::Status Authenticate(const std::string& username,
                            const std::string& password) {
    urmom::v1::AuthenticateRequest request;
    request.set_username(username);
    request.set_password(password);
    authenticate_response_.Clear();
    return service_->Authenticate(nullptr, &request, &authenticate_response_);
  }

  sqlite3* database_ = nullptr;
  std::filesystem::path database_path_;
  std::unique_ptr<AuthServiceImpl> service_;
  urmom::v1::UserInfoResponse user_info_response_;
  urmom::v1::AuthenticateResponse authenticate_response_;
};

TEST_F(AuthServiceTest, UsesVersionedWireServiceName) {
  EXPECT_STREQ(urmom::v1::AuthService::service_full_name(),
               "urmom.v1.AuthService");
}

TEST_F(AuthServiceTest, UserInfoReturnsActiveUserApps) {
  const grpc::Status status = UserInfo("alice");

  ASSERT_TRUE(status.ok()) << status.error_message();
  ASSERT_TRUE(user_info_response_.has_userinfo());
  EXPECT_TRUE(user_info_response_.userinfo().is_active());
  EXPECT_THAT(user_info_response_.userinfo().apps(),
              ElementsAre("alpha", "zeta"));
}

TEST_F(AuthServiceTest, UserInfoReturnsInactiveUserWithoutApps) {
  const grpc::Status status = UserInfo("bob");

  ASSERT_TRUE(status.ok()) << status.error_message();
  ASSERT_TRUE(user_info_response_.has_userinfo());
  EXPECT_FALSE(user_info_response_.userinfo().is_active());
  EXPECT_TRUE(user_info_response_.userinfo().apps().empty());
}

TEST_F(AuthServiceTest, UserInfoReturnsNotFoundForMissingUser) {
  const grpc::Status status = UserInfo("carol");

  EXPECT_EQ(status.error_code(), grpc::StatusCode::NOT_FOUND);
  EXPECT_EQ(status.error_message(), "user not found");
  EXPECT_FALSE(user_info_response_.has_userinfo());
}

TEST_F(AuthServiceTest, AuthenticateReturnsUserInfoForValidPassword) {
  const grpc::Status status = Authenticate("alice", "correct horse");

  ASSERT_TRUE(status.ok()) << status.error_message();
  EXPECT_TRUE(authenticate_response_.authenticated());
  ASSERT_TRUE(authenticate_response_.has_userinfo());
  EXPECT_TRUE(authenticate_response_.userinfo().is_active());
  EXPECT_THAT(authenticate_response_.userinfo().apps(),
              ElementsAre("alpha", "zeta"));
}

TEST_F(AuthServiceTest, AuthenticateOmitsUserInfoForInvalidPassword) {
  const grpc::Status status = Authenticate("alice", "wrong password");

  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_FALSE(authenticate_response_.authenticated());
  EXPECT_FALSE(authenticate_response_.has_userinfo());
}

TEST_F(AuthServiceTest, AuthenticateReturnsNotFoundForMissingUser) {
  const grpc::Status status = Authenticate("carol", "password");

  EXPECT_EQ(status.error_code(), grpc::StatusCode::NOT_FOUND);
  EXPECT_FALSE(authenticate_response_.authenticated());
  EXPECT_FALSE(authenticate_response_.has_userinfo());
}

}  // namespace
