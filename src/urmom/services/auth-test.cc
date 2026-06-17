#include "urmom/services/auth.hpp"

#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include <gmock/gmock.h>
#include <gtest/gtest.h>

namespace {

using ::testing::ElementsAre;
using ::testing::Return;
using ::testing::StrictMock;
using ::testing::Throw;
using urmom::services::AuthServiceImpl;
using urmom::services::AuthUserDetails;
using urmom::services::AuthUserDetailsReader;

class MockAuthUserDetailsReader : public AuthUserDetailsReader {
 public:
  MOCK_METHOD(std::optional<AuthUserDetails>,
              UserDetailsByUsername,
              (const std::string& username),
              (override));
};

class AuthServiceTest : public ::testing::Test {
 protected:
  grpc::Status UserDetails(const std::string& username) {
    auth::UserDetailsRequest request;
    request.set_username(username);
    return service.UserDetails(nullptr, &request, &response);
  }

  std::shared_ptr<StrictMock<MockAuthUserDetailsReader>> reader =
      std::make_shared<StrictMock<MockAuthUserDetailsReader>>();
  AuthServiceImpl service{reader};
  auth::UserDetailsResponse response;
};

TEST_F(AuthServiceTest, UserDetailsReturnsActiveUserApps) {
  EXPECT_CALL(*reader, UserDetailsByUsername("alice"))
      .WillOnce(Return(std::optional<AuthUserDetails>(
          AuthUserDetails{true, {"alpha", "zeta"}})));

  const grpc::Status status = UserDetails("alice");

  ASSERT_TRUE(status.ok()) << status.error_message();
  EXPECT_TRUE(response.is_active());
  EXPECT_THAT(response.apps(), ElementsAre("alpha", "zeta"));
}

TEST_F(AuthServiceTest, UserDetailsReturnsInactiveUserWithoutApps) {
  EXPECT_CALL(*reader, UserDetailsByUsername("bob"))
      .WillOnce(
          Return(std::optional<AuthUserDetails>(AuthUserDetails{false, {}})));

  const grpc::Status status = UserDetails("bob");

  ASSERT_TRUE(status.ok()) << status.error_message();
  EXPECT_FALSE(response.is_active());
  EXPECT_EQ(response.apps_size(), 0);
}

TEST_F(AuthServiceTest, UserDetailsReturnsNotFoundForMissingUser) {
  EXPECT_CALL(*reader, UserDetailsByUsername("carol"))
      .WillOnce(Return(std::nullopt));

  const grpc::Status status = UserDetails("carol");

  EXPECT_EQ(status.error_code(), grpc::StatusCode::NOT_FOUND);
  EXPECT_EQ(status.error_message(), "user not found");
}

TEST_F(AuthServiceTest, UserDetailsReturnsInternalWhenReaderFails) {
  EXPECT_CALL(*reader, UserDetailsByUsername("alice"))
      .WillOnce(Throw(std::runtime_error("database down")));

  const grpc::Status status = UserDetails("alice");

  EXPECT_EQ(status.error_code(), grpc::StatusCode::INTERNAL);
  EXPECT_EQ(status.error_message(), "database down");
}

}  // namespace
