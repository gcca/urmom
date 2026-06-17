#pragma once

#include <string>

#include "auth.grpc.pb.h"

namespace urmom::services {

class AuthServiceImpl final : public auth::AuthService::Service {
 public:
  explicit AuthServiceImpl(std::string database_path);

  grpc::Status UserDetails(grpc::ServerContext* context,
                           const auth::UserDetailsRequest* request,
                           auth::UserDetailsResponse* response) override;

 private:
  std::string database_path_;
};

}  // namespace urmom::services