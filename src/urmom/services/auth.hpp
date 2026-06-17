#pragma once

#include <string>
#include <utility>

#include "auth.grpc.pb.h"
#include "auth.pb.h"

namespace urmom::services {

class AuthServiceImpl final : public v1::AuthService::Service {
 public:
  explicit AuthServiceImpl(std::string dbname) : dbname_{std::move(dbname)} {}

  grpc::Status UserInfo(grpc::ServerContext* context,
                        const v1::UserInfoRequest* request,
                        v1::UserInfoResponse* response) override;

  grpc::Status Authenticate(grpc::ServerContext* context,
                            const v1::AuthenticateRequest* request,
                            v1::AuthenticateResponse* response) override;

 private:
  grpc::Status LoadUserInfo(const std::string& username,
                            v1::UserInfo* userinfo) const;

  std::string dbname_;
};

}  // namespace urmom::services
