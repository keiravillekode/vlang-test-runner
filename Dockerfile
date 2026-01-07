FROM alpine:3.17 AS install

# The official vlang -dev images are currently well behind the mainstream version of V, and cannot
# be pinned to a known version. Alas, the official installation instructions involve a makefile
# that `git clone`s the vlang/vc repo, so can't be relied on to be deterministic either.
# However, pre-built releases are now available, which is a reliable route for our purposes.

# Specify the release of V to download. 
ARG release_tag=0.4.8
ARG release_filename=v_linux.zip

WORKDIR /opt/vlang
RUN apk add --no-cache wget unzip
RUN wget https://github.com/vlang/v/releases/download/${release_tag}/${release_filename}
# Extract the zip and put the contents in current directory.
RUN unzip ${release_filename} -d ./tmp && rm ${release_filename} && mv ./tmp/*/* .
# And finally, check the executable is where we expect it
RUN test -f v && test -x v


FROM debian:bookworm AS run
# While the v in the vlang -dev images is out of date, the base images still contain
# valuable run time pre-requisites, so we derive our run image from here:
# https://github.com/vlang/docker/blob/master/docker/base/Dockerfile.debian
# Note the pre-compiled release of V does not run on Alpine, hence the switch to Debian.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    clang llvm-dev && \
    apt-get clean && rm -rf /var/cache/apt/archives/* && \
    rm -rf /var/lib/apt/lists/*
# Copy the prebuilt V compiler
COPY --from=install /opt/vlang /opt/vlang
# Add vlang to path
ENV PATH="/opt/vlang:${PATH}"
# Test it
RUN v -version

# Finally, we can do our business...
RUN apt-get update && \
		apt-get install -y --no-install-recommends \
		jq sed && \
    apt-get clean && rm -rf /var/cache/apt/archives/* && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/sample
COPY pre-compile/ ./
RUN v -stats test run_test.v

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
