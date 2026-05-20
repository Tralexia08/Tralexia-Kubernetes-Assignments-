
# Assignment 02 — Tralexia Audige

**GitHub username:** Tralexia08  
**Date completed:** 2026-05-18  
**Language chosen:** Python

## 1. The image I built

- Final image ID: `sha256:9e41447b956059e497bf2fd25ccd9c5002f22dc9c72e72b5b3a5efdf4177fd06`
- Image size: `109MB`
- Number of layers: `14`

### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY app.py .

ENV PORT=8000
EXPOSE 8000

CMD ["python", "app.py"]
```

### .dockerignore

```text
.git
.gitignore
node_modules
__pycache__
*.pyc
*.log
README.md
```

## 2. Answers to the 8 questions

**Q1 — what `.dockerignore` affects:** `.dockerignore` tells Docker which files and folders to exclude from the build context. Excluding `.git` matters because Docker still sends the project folder during the build process, even if the Dockerfile never copies `.git`.

**Q2 — what is the image ID a hash of:** The image ID is a hash of the image contents and layers. Docker uses it to uniquely identify the built image.

**Q3 — largest layer and why:** The largest layer was the `109MB` base image layer from `python:3.11-slim`. It was the largest because it contains the operating system files and Python runtime needed for the container.

**Q4 — `--memory 64m` shows up as what value:** The value showed up as `67108864`. Docker inspect displays memory in bytes, while Docker stats shows it in a more readable format like `64MiB`.

**Q5 — PID of my app inside the container:** The app process inside the container was PID `1`. This shows the Python app was started as the main process directly from the Dockerfile `CMD`.

**Q6 — `stop` vs `kill`, and which for a database:** `docker stop` gracefully shuts down a container by sending SIGTERM first and allowing cleanup before stopping. `docker kill` immediately stops the container using SIGKILL. For a database container, I would use `stop` because it allows the database time to safely save data and shut down properly.

**Q7 — what same-IMAGE-ID-across-tags proves:** This proves Docker tags are just labels pointing to the same underlying image. Docker does not duplicate image data when multiple tags reference the same image.

**Q8 — tag vs digest mutability:** A tag like `alpine:3.19` can change over time if it is re-tagged to a different image. A digest always points to one exact immutable image version.


## 3. Evidence

### docker image history

```bash
docker image history cohort-greet:0.1.0
```

```text
IMAGE          CREATED          CREATED BY                                      SIZE
9e41447b9560   10 minutes ago   CMD ["python" "app.py"]                         0B
<missing>      10 minutes ago   EXPOSE [8000/tcp]                               0B
<missing>      10 minutes ago   ENV PORT=8000                                   0B
<missing>      10 minutes ago   COPY app.py . # buildkit                        12.3kB
<missing>      10 minutes ago   WORKDIR /app                                    8.19kB
...trimmed...
<missing>      3 weeks ago      # debian.sh --arch 'arm64' ...                  109MB
```

### detached container run

```bash
docker container run -d \
  --name greet \
  -p 8080:8000 \
  -e STUDENT_NAME="<your name>" \
  -e GREETING="hi" \
  --restart unless-stopped \
  --memory 64m \
  --cpus 0.25 \
  cohort-greet:0.1.0
```

```text
dc9e0535f4247836e3817442a06e5ac28b0917186befa53712efe3c8d49e88a1
```

### docker container logs

```bash
docker container logs greet
```

```text
listening on :8000
[req] ... GET /
```

### docker container stats

```bash
docker container stats --no-stream greet
```

```text
CONTAINER ID   NAME    CPU %   MEM USAGE / LIMIT   MEM %    NET I/O       BLOCK I/O   PIDS
dc9e0535f424   greet   8.44%   13.61MiB / 64MiB    21.26%   806B / 180B    0B / 0B     1
```

### restart policy and memory

```bash
docker container inspect -f '{{.HostConfig.RestartPolicy.Name}} {{.HostConfig.Memory}}' greet
```

```text
unless-stopped 67108864
```

### image tags

```bash
docker image ls cohort-greet
```

```text
REPOSITORY      TAG      IMAGE ID       CREATED          SIZE
cohort-greet    0.1.0    9e41447b9560   10 minutes ago   109MB
cohort-greet    0.1      9e41447b9560   10 minutes ago   109MB
cohort-greet    latest   9e41447b9560   10 minutes ago   109MB
```

### pushed image URL

```text
docker.io/tralexia08/cohort-greet:0.1.0
```

## 4. One thing that surprised me

One thing that surprised me was how containers are isolated but still able to communicate with my computer through port mapping. It finally clicked for me when I used `-p 8080:8000` and realized Docker was forwarding traffic from my machine into the container. I also did not expect something as small as my app file to still create an image over 100MB because of everything included in the base image.

## 5. One thing I'm still unsure about

I am still still unsure about when containers should be separated into multiple services versus kept together in one container.

