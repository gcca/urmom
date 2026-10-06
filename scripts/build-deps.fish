#!/usr/bin/env fish

function fail
    echo "build-deps: $argv" >&2
    exit 1
end

function step
    echo "build-deps: $argv" >&2
end

set -l usage "usage: build-deps.fish [--push] [--local-tag=IMAGE] [--remote-tag=IMAGE]"

argparse h/help push 'local-tag=' 'remote-tag=' -- $argv
or fail $usage

if set -q _flag_help
    echo $usage
    echo "  1. build deps for the host platform and load it as the local tag"
    echo "  2. build execute-with-tools on top of the local deps image and smoke-test it"
    echo "  3. --push: push the host-platform image as REMOTE-TAG-ARCH"
    echo "  deps runs SBCL, so it builds natively only; the multi-arch REMOTE-TAG"
    echo "  manifest is published by .github/workflows/package-deps.yaml"
    echo "  defaults: --local-tag=urmom:deps"
    echo "            --remote-tag=ghcr.io/gcca/urmom:deps"
    exit 0
end

set -l script_file (status --current-filename)
test -n "$script_file"
or fail "could not resolve the script path"

set -l script_dir (path dirname (path resolve "$script_file"))
set -l repo_root (path dirname "$script_dir")

for file in Dockerfile deps/Dockerfile CMakeLists.txt cmd/build.lisp
    test -f "$repo_root/$file"
    or fail "$file was not found at $repo_root"
end

set -l local_tag urmom:deps
set -q _flag_local_tag; and set local_tag $_flag_local_tag
set -l remote_tag ghcr.io/gcca/urmom:deps
set -q _flag_remote_tag; and set remote_tag $_flag_remote_tag
set -l check_tag urmom:deps-check

set -l host_arch
switch (uname -m)
    case arm64 aarch64
        set host_arch arm64
    case x86_64 amd64
        set host_arch amd64
    case '*'
        fail "unsupported host architecture: "(uname -m)
end
set -l host_platform linux/$host_arch

set -l deps_digest (shasum -a 256 "$repo_root/deps/Dockerfile" | string split -f1 ' ')
or fail "could not hash deps/Dockerfile"

set -l labels \
    --label org.opencontainers.image.source=https://github.com/gcca/urmom \
    --label org.opencontainers.image.revision=deps-dockerfile-sha256:$deps_digest

step "building $local_tag for $host_platform"
docker buildx build \
    --file "$repo_root/deps/Dockerfile" \
    --target deps \
    --platform $host_platform \
    --tag $local_tag \
    $labels \
    --load \
    "$repo_root"
or fail "local deps build failed"

step "building $check_tag on $local_tag"
docker buildx build \
    --build-arg DEPS_IMAGE=$local_tag \
    --target execute-with-tools \
    --platform $host_platform \
    --tag $check_tag \
    --load \
    "$repo_root"
or fail "app build on $local_tag failed"

step "smoke-testing $check_tag"
set -l failed
for command in urmom urmom-create_user
    set -l output (docker run --rm --entrypoint $command $check_tag --help 2>&1)
    or set -a failed "$command --help: $output"
end
docker image rm $check_tag >/dev/null
test -z "$failed"
or fail "smoke test on $check_tag failed: $failed"

if not set -q _flag_push
    step "done: $local_tag"
    exit 0
end

step "pushing $remote_tag-$host_arch"
docker tag $local_tag $remote_tag-$host_arch
and docker push $remote_tag-$host_arch
or fail "remote deps push failed"

step "done: $local_tag, $remote_tag-$host_arch (publish $remote_tag via package-deps.yaml)"
