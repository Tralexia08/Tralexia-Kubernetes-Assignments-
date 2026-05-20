# Assignment 03 — Tralexia Audige

**GitHub username:** tralexia08  
**Date completed:** 2026-05-19  
**Git SHA of submitted app:** 041abb0  

## 1. Size comparison table

| Variant | Size | Layers | Stop time | Exit code |
|---|---:|---:|---:|---:|
| `cohort-greet:naive` | 1.63GB | XX | ~5.0 s | 137 |
| `cohort-greet:multi` | 259MB | XX | ~0.03 s | 0 |

(Layers = output of `docker image history <tag> | wc -l` minus 1 for the header.)

## 2. Final image digest

`sha256:e77c82424bd57330c56ffc067b68d9159ac59e9d47797878ddf66821e639621c`

## 3. Answers to the 7 questions

**Q1 — naive size + stop behaviour + why:**  
The `cohort-greet:naive` image size was 1.63GB. The container exited with code 137, which means Docker had to force-kill it after it did not shut down cleanly. This happened because the naive Dockerfile used shell form `CMD`, so SIGTERM did not reach the Gunicorn process directly.

**Q2 — build output, CACHED vs rebuilt:**  
After making a small edit to `app.py`, the rebuild showed that the `pip install` layer was cached. The dependency layers stayed cached because `requirements.txt` was copied before `app.py`. Only the application-code layer had to be rebuilt because only `app.py` changed.

**Q3 — new stop time/exit + which change:**  
The improved image stopped in about 0.03 seconds and exited with code 0. The change responsible was using exec form for `CMD`: `CMD ["gunicorn", "-b", "0.0.0.0:8080", "app:app"]`. This lets SIGTERM reach Gunicorn directly so the container shuts down gracefully.

**Q4 — size reduction breakdown:**  
The naive image was 1.63GB and the multi-stage image was 259MB, so the image shrank by about 84.1%. The main savings came from using `python:3.11-slim`, using a multi-stage build, copying only `/opt/venv` into the runtime image, and using `.dockerignore` to avoid copying unnecessary files.

**Q5 — cache-mount timings + CI relevance:**  
The first build took 6.824 seconds, and the second build took 4.820 seconds. The second build saved about 2 seconds because the BuildKit cache mount preserved pip’s download cache. This matters in CI because Docker layer cache may be cold, but a remote cache mount can still speed up dependency installs.

**Q6 — secret marker + what `ARG` would leak:**  
The secret marker output was `dd4b`, and the leak check returned `no leak`. This proves the secret was readable during build but the full token was not stored in image history. If I had used `ARG PYPI_TOKEN`, the token could have appeared in `docker history` or image metadata.

**Q7 — tag vs digest for k8s manifest:**  
For a normal Kubernetes manifest, I would use the git SHA tag like `cohort-greet:git-041abb0` because it connects the image to a specific commit. If exact reproducibility is required, I would use the digest instead: `cohort-greet@sha256:e77c82424bd57330c56ffc067b68d9159ac59e9d47797878ddf66821e639621c`, because digests are immutable.

## 4. Files

### Final `Dockerfile`
```dockerfile
# syntax=docker/dockerfile:1.7

# ---- build stage ----
FROM python:3.11-slim AS build

RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

WORKDIR /app

COPY requirements.txt .

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

# ---- runtime stage ----
FROM python:3.11-slim AS runtime

COPY --from=build /opt/venv /opt/venv

ENV PATH=/opt/venv/bin:$PATH

WORKDIR /app

RUN useradd --uid 1000 app && chown -R app:app /app

COPY app.py .

EXPOSE 8080

HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')"

USER app

CMD ["gunicorn", "-b", "0.0.0.0:8080", "app:app"]
```

### `Dockerfile.naive`
```dockerfile
FROM python:3.11
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 8080
CMD gunicorn -b 0.0.0.0:8080 app:app
```

### `Dockerfile.secret`
```dockerfile
# syntax=docker/dockerfile:1.7

FROM python:3.11-slim

RUN --mount=type=secret,id=pypi_token \
    sh -c 'cat /run/secrets/pypi_token | cut -c1-4 > /where-token-was-used'
```

### `.dockerignore`
```text
.git
.gitignore
__pycache__/
*.pyc
Dockerfile*
*.md
.env*
```

## 5. Evidence

```text
docker image ls cohort-greet --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}'

REPOSITORY      TAG             IMAGE ID
cohort-greet    secret          d5fa0c6fe751
cohort-greet    0.1.0           e77c82424bd5
cohort-greet    0.1.0-041abb0   e77c82424bd5
cohort-greet    git-041abb0     e77c82424bd5
cohort-greet    multi           e77c82424bd5
cohort-greet    prod            da7cf31836d9
cohort-greet    naive           0f593b225a2f
```

```text
docker container run --rm cohort-greet:secret cat /where-token-was-used

dd4b
```

```text
docker image history --no-trunc cohort-greet:secret | grep -i "$PYPI_TOKEN" && echo "LEAKED" || echo "no leak"

no leak
```

```text
docker container run --rm hadolint/hadolint < Dockerfile

(no output)
```

```text
Cold build:
docker image build --no-cache -t cohort-greet:multi . 0.12s user 0.12s system 3% cpu 6.824 total

Warm cache mount build:
docker image build --no-cache -t cohort-greet:multi . 0.10s user 0.11s system 4% cpu 4.820 total
```

## 6. One trade-off I had to make

I chose to use `python:3.11-slim` instead of the full `python:3.11` image because it made the final image much smaller. The trade-off is that slim images include fewer built-in tools and libraries, which can make debugging or installing some dependencies harder. I chose the slim image because the app is simple and does not need the extra tools from the full image.

## 7. One thing I'm still unsure about

I am still unsure how to decide the best base image for larger production applications.