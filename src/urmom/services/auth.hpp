#pragma once

#include <string>
#include <utility>

#include "auth.grpc.pb.h"
#include "auth.pb.h"

namespace urmom::services {

class AuthServiceImpl final : public auth::AuthService::Service {
 public:
  explicit AuthServiceImpl(std::string dbname) : dbname_{std::move(dbname)} {}

  grpc::Status UserDetails(grpc::ServerContext* context,
                           const auth::UserDetailsRequest* request,
                           auth::UserDetailsResponse* response) override;

  grpc::Status Authenticate(grpc::ServerContext* context,
                            const auth::AuthenticateRequest* request,
                            auth::AuthenticateResponse* response) override;

 private:
  std::string dbname_;
};

}  // namespace urmom::services
