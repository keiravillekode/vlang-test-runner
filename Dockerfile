FROM debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4 AS base

FROM base AS install

# The official vlang -dev images are currently well behind the mainstream version of V, and cannot
# be pinned to a known version. Alas, the official installation instructions involve a makefile
# that `git clone`s the vlang/vc repo, so can't be relied on to be deterministic either.
# However, pre-built releases are now available, which is a reliable route for our purposes.

# Specify the release of V to download. 
ARG release_tag=0.5.2
ARG release_filename=v_linux.zip

WORKDIR /opt/vlang
RUN apt-get update && \
    apt-get install --yes --no-install-recommends unzip
ADD https://github.com/vlang/v/releases/download/${release_tag}/${release_filename} /opt/vlang/${release_filename}
# Extract the zip and put the contents in current directory.
RUN unzip ${release_filename} -d ./tmp && rm ${release_filename} && mv ./tmp/*/* .
# And finally, check the executable is where we expect it
RUN test -f v && test -x v

FROM base
# While the v in the vlang -dev images is out of date, the base images still contain
# valuable run time pre-requisites, so we derive our run image from here:
# https://github.com/vlang/docker/blob/master/docker/base/Dockerfile.debian
# V compiles its generated C with tcc (the Tiny C Compiler, ~0.3 MB) instead of
# clang+llvm-dev (~880 MB):
#   libc6-dev  - headers/crt files tcc needs to produce executables
#   libatomic1 - V's runtime links -latomic (tcc can't find it otherwise)
# V 0.4.x invoked the default `cc` for its own internal tools, so tcc is made the
# default cc. From 0.5 V ships its own TinyCC in the release archive
# (thirdparty/tcc/tcc.exe, an ELF binary despite the name) and prefers it - see
# vlib/v/pref/default.v, `try_to_use_tcc_by_default`. The system tcc is kept
# deliberately: it is the fallback V reaches for via `first_available_ccompiler`
# if the bundled one ever fails, so it is not dead weight.
RUN apt-get update && \
    apt-get install --yes --no-install-recommends tcc libc6-dev libatomic1 jq sed && \
    ln -sf /usr/bin/tcc /usr/local/bin/cc && \
    ln -sf libatomic.so.1 "$(dirname "$(find / -name libatomic.so.1 -print -quit)")/libatomic.so" && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Copy the prebuilt V compiler
COPY --from=install /opt/vlang /opt/vlang
# Add vlang to path
ENV PATH="/opt/vlang:${PATH}"
# Test it
RUN v -version

# Finally, we can do our business...
WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
