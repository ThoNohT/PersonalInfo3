# PersonalInfo3

Third installment of personal information manager for an employee.

# Running

So far, only linux is supported.

- Ensure [Gleam](https://gleam.run) is installed.
- Ensure [Erlang](https://www.erlang.org) is installed.
    - [wisp](https://hexdocs.pm/wisp/index.html) requires at least Erlang/OTP 26. At the time of witing this guide, the Linux Mint repositories contain Erlang/OTP 24. If your distribution has a similar problem, you could consider using a tool like [mise](https://mise.jdx.dev/lang/erlang.html) to install the latest version of Erlang/OTP.
    - Other packages needed to run mise: curl, git, build-essential, automake, autoconf, libssl-dev, libncurses-dev

```sh
# Install mise.
curl https://mise.run | sh

# Activate mise in bash.
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc

# Install and use the latest version of Erlang.
mise use -g erlang@27.3
```

- Build the server and client and run the server.
    - Other packages needed to build the server: rebar3
    - Other packages needed to build the client: esbuild

```sh
# Build the client.
./client/build.sh build

# Build the server.
./server/build.sh build

# Run the server.
./server/build.sh run
```
