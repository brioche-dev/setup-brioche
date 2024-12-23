abi <abi/4.0>,
include <tunables/global>

# Enable unprivileged user namespaces for Brioche. See this Ubuntu blog post
# for more context:
# https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces
${BRIOCHE_INSTALL_PATH} flags=(default_allow) {
  userns,
}
