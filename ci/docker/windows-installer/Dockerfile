# Toolchain for the Windows installer (ci/windows/maszyna-reloaded.nsi). The export is a zip with
# the game and libmaszyna.64.dll beside it; run from inside the zip, Explorer extracts the exe
# alone and the game starts without its library. NSIS builds the installer natively on Linux, so
# no wine is needed. The checkout is never copied in: the Makefile mounts it (see release-windows).
# Debian's official image from the AWS mirror, never Docker Hub: its anonymous pulls time out the CI
FROM public.ecr.aws/docker/library/debian:bookworm-slim
# links the ghcr.io package to its repository
LABEL org.opencontainers.image.source=https://github.com/MaSzyna-Reloaded/maszyna-reloaded

RUN apt-get update \
    && apt-get install -y --no-install-recommends nsis unzip \
    && rm -rf /var/lib/apt/lists/*

ENV HOME=/tmp
