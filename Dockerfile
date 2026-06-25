ARG BASE_IMAGE

# =============================================================================
# Renovate ECR pull-through cache test cases
#
# Each FROM below exercises one branch of the replacement packageRules in
# .github/renovate.json. The "Expected:" comment is what Renovate should
# rewrite the image to. Stages are named and unreferenced, so BuildKit skips
# them at build time — they exist purely for Renovate to scan.
#
# ECR prefix: 111111111111.dkr.ecr.ap-southeast-2.amazonaws.com/
# =============================================================================

# --- SHOULD be rewritten -----------------------------------------------------

# public.ecr.aws (registry kept in name)
# Expected: .../public.ecr.aws/docker/library/busybox:stable
FROM public.ecr.aws/docker/library/busybox:stable AS test-public-ecr

# registry.k8s.io (registry kept in name)
# Expected: .../registry.k8s.io/pause:3.10
FROM registry.k8s.io/pause:3.10 AS test-registry-k8s

# quay.io (registry kept in name)
# Expected: .../quay.io/jitesoft/alpine:latest
FROM 111111111111.dkr.ecr.ap-southeast-2.amazonaws.com/quay.io/jitesoft/alpine:latest AS test-quay

# docker.io, explicitly qualified + namespaced
# Expected: .../docker.io/amazon/aws-cli:latest
FROM docker.io/amazon/aws-cli:latest AS test-dockerio-namespaced

# docker.io, explicitly qualified official (library) image
# Expected: .../docker.io/library/busybox:stable
FROM docker.io/library/busybox:stable AS test-dockerio-library

# Docker Hub bare official image (no registry, no namespace)
# Expected: .../docker.io/library/node:22-alpine
FROM node:22-alpine AS test-hub-official

# Docker Hub bare namespaced image (no registry)
# Expected: .../docker.io/amazon/aws-cli:latest
FROM amazon/aws-cli:latest AS test-hub-namespaced

# --- Control cases: should NOT be rewritten ----------------------------------

# gcr.io is not in the list — leave untouched
# Expected: unchanged
FROM gcr.io/distroless/static-debian12:latest AS test-gcr-untouched

# Already routed through ECR — must NOT be double-prefixed
# Expected: unchanged
FROM 111111111111.dkr.ecr.ap-southeast-2.amazonaws.com/docker.io/library/busybox:stable AS test-already-ecr

# =============================================================================
# Real build (kept last so `runtime` remains the default build target)
# =============================================================================

FROM public.ecr.aws/docker/library/node:22-alpine AS build

COPY . .

RUN pnpm install --offline
RUN pnpm build
RUN pnpm --filter api --prod --offline deploy api

FROM gcr.io/distroless/nodejs24-debian13@sha256:b25d2acae94fcf57d27f3ac29135ecdce9c0be1e8585ef52262f0dde6b36ce72 AS runtime

WORKDIR /workdir

COPY --from=build /workdir/api .

ENV NODE_ENV=production

# https://nodejs.org/api/cli.html#cli_node_options_options
ENV NODE_OPTIONS=--enable-source-maps

ARG PORT=8001
ENV PORT=${PORT}
EXPOSE ${PORT}

CMD ["./lib/listen.js"]
