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