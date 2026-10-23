# Enforcing Dockerfile Best Practices with Hadolint in CI

| Field | Entry |
|---|---|
| Case study topic | Enforcing Dockerfile best practices through automated linting in a CI pipeline |
| Tool selected | [Hadolint](https://github.com/hadolint/hadolint) v2.12.0 |
| CI platform | GitHub Actions (`hadolint/hadolint-action@v3.1.0`) |

## Project layout

```
Devops_IA2/
├── app/
│   ├── app.py                  # tiny Flask app (the thing we containerise)
│   └── requirements.txt
├── demo/
│   ├── step0-bad.Dockerfile    # deliberately bad: 10 findings
│   ├── step1-pin-base.Dockerfile
│   ├── step2-apt.Dockerfile
│   ├── step3-copy.Dockerfile
│   └── step4-final.Dockerfile  # clean: 0 findings
├── scripts/
│   ├── lint.ps1                # run Hadolint via Docker (Windows)
│   └── lint.sh                 # run Hadolint via Docker (Linux/macOS/Git Bash)
├── .github/workflows/lint.yml  # CI: lint, then build only if lint passes
├── .hadolint.yaml              # threshold, ignored rules, severity overrides
├── .dockerignore
└── Dockerfile                  # the file CI lints (currently the clean version)
```

## Prerequisites

- Docker Desktop running (Hadolint runs as a container, so you don't need to install it)
- A GitHub account and an empty GitHub repository for the CI part

```powershell
docker pull hadolint/hadolint:v2.12.0
```

---

## Part 1: Lint the bad Dockerfile

`demo/step0-bad.Dockerfile`:

```dockerfile
FROM python:latest
RUN apt-get update
RUN apt-get install curl
ADD . /app
WORKDIR /app
RUN pip install -r app/requirements.txt
USER root
EXPOSE 5000
CMD python app/app.py
```

Run Hadolint (this is the plain command from the brief):

```powershell
Get-Content demo\step0-bad.Dockerfile | docker run --rm -i hadolint/hadolint:v2.12.0
```

(In Git Bash or Linux: `docker run --rm -i hadolint/hadolint < demo/step0-bad.Dockerfile`)

Actual output:

```
-:2  DL3007 warning: Using latest is prone to errors if the image will ever update. Pin the version explicitly to a release tag
-:4  DL3009 info:    Delete the apt-get lists after installing something
-:5  DL3059 info:    Multiple consecutive `RUN` instructions. Consider consolidation.
-:5  DL3008 warning: Pin versions in apt get install.
-:5  DL3014 warning: Use the `-y` switch to avoid manual input
-:5  DL3015 info:    Avoid additional packages by specifying `--no-install-recommends`
-:7  DL3020 error:   Use COPY instead of ADD for files and folders
-:10 DL3042 warning: Avoid use of cache directory with pip. Use `pip install --no-cache-dir`
-:12 DL3002 warning: Last USER should not be root
-:14 DL3025 warning: Use arguments JSON notation for CMD and ENTRYPOINT arguments
```

The exit code is **1**, which is what makes a CI job fail.

> **Notes on rule codes**
> - `FROM python:latest` triggers **DL3007**. DL3006 is a different rule: it fires when there is *no tag at all* (`FROM python`).
> - **DL3002** fires only when the last `USER` is explicitly `root`. A Dockerfile with *no* `USER` line still runs as root, but Hadolint stays silent, so the bad file includes `USER root` to make the problem visible.

---

## Part 2: Fix the warnings one at a time

Lint each step to watch the count drop:

```powershell
.\scripts\lint.ps1 demo\step1-pin-base.Dockerfile
```

| Step | Change | Rules fixed | Findings left |
|---|---|---|---|
| 0 | the bad file | — | 10 |
| 1 | `FROM python:3.12.7-slim-bookworm` | DL3007 | 9 |
| 2 | single `RUN`: `apt-get update && apt-get install -y --no-install-recommends curl=7.88.1-10+deb12u15 && rm -rf /var/lib/apt/lists/*` | DL3008, DL3009, DL3014, DL3015, DL3059 | 4 |
| 3 | `COPY` instead of `ADD`; `pip install --no-cache-dir`; copy `requirements.txt` first for layer caching | DL3020, DL3042 | 2 |
| 4 | create `appuser` and `USER appuser`; exec-form `CMD ["python", "app.py"]` | DL3002, DL3025 | **0** |

Why each fix matters:

| Rule | Problem | Why it matters |
|---|---|---|
| DL3007 | `:latest` tag | Builds aren't reproducible; a new upstream release can silently break the image. |
| DL3008 | unpinned apt package | Same problem at the package level. |
| DL3009 | apt lists not deleted | Adds tens of MB of package indexes to the image. |
| DL3014 | no `-y` | The build can hang waiting for a yes/no prompt. |
| DL3015 | recommended packages installed | Larger image and bigger attack surface. |
| DL3059 | separate `RUN`s | Stale `apt-get update` cache layer; more layers. |
| DL3020 | `ADD` for local files | `ADD` also extracts archives and fetches URLs, which can be surprising. `COPY` does only one thing. |
| DL3042 | pip cache kept | Wasted space in the image. |
| DL3002 | runs as root | A container breakout gives the attacker root. |
| DL3025 | shell-form `CMD` | Runs under `/bin/sh`, so `SIGTERM` never reaches Python and `docker stop` waits 10 s before killing it. |

The final, clean result is the root [`Dockerfile`](Dockerfile). Linting it prints nothing and exits 0:

```powershell
.\scripts\lint.ps1          # ==> hadolint Dockerfile  /  (no issues found)
```

> **Trade-off: pinned apt versions.** Debian removes old package versions from its mirrors, so an exact pin like `curl=7.88.1-10+deb12u15` will eventually make `apt-get install` fail. That's the cost of reproducibility. To check the current version:
> `docker run --rm python:3.12.7-slim-bookworm sh -c "apt-get update -qq && apt-cache policy curl"`
> Many teams ignore DL3008 instead (see Part 4).

---

## Part 3: Enforce it in CI (GitHub Actions)

[`.github/workflows/lint.yml`](.github/workflows/lint.yml) runs on every push and pull request:

1. **hadolint** job: lints `Dockerfile` using `.hadolint.yaml`. Any finding at `warning` or above fails the job.
2. **build** job: `needs: hadolint`, so the image is built **only** when linting passes.

### Push the project to GitHub

```powershell
cd C:\Users\SAHIL\OneDrive\Desktop\Devops_IA2
git init -b main
git add .
git commit -m "Hadolint case study: clean Dockerfile + CI lint"
git remote add origin https://github.com/<your-username>/<repo-name>.git
git push -u origin main
```

Open the **Actions** tab. The run should be **green** ✅.

### Show a red build

```powershell
Copy-Item demo\step0-bad.Dockerfile Dockerfile -Force
git commit -am "Introduce a bad Dockerfile"
git push
```

The `hadolint` job fails ❌ and lists every finding (also shown as annotations on the commit). The `build` job is **skipped**, so the bad image never gets built.

### Fix it and go green again

```powershell
Copy-Item demo\step4-final.Dockerfile Dockerfile -Force
git commit -am "Fix Dockerfile per Hadolint"
git push
```

Both jobs pass ✅.

> **Tip:** to make the gate stick, go to *Settings → Branches → Add branch protection rule* for `main` and mark **Lint Dockerfile with Hadolint** as a required status check. Pull requests with a bad Dockerfile then can't be merged.

---

## Part 4 (optional): Configure Hadolint with `.hadolint.yaml`

[`.hadolint.yaml`](.hadolint.yaml) is read automatically from the repo root:

```yaml
failure-threshold: warning     # info/style findings are reported but don't fail
ignored: []                    # e.g. [DL3008] to stop requiring pinned apt versions
trustedRegistries:
  - docker.io                  # DL3026: only allow images from these registries
override:
  error:
    - DL3002                   # running as root -> hard error
    - DL3007                   # :latest -> hard error
```

Lint the bad file **with** the config (the scripts mount it into the container):

```powershell
.\scripts\lint.ps1 demo\step0-bad.Dockerfile
```

DL3007 and DL3002 now report as **error** instead of warning.

Things to try live:

| Edit to `.hadolint.yaml` | Lint this file | Result |
|---|---|---|
| `failure-threshold: error` | `demo/step3-copy.Dockerfile` | **Still fails (exit 1):** DL3002 is promoted to `error` by `override`. |
| …and also remove `DL3002` from `override` | `demo/step3-copy.Dockerfile` | **Passes (exit 0):** both remaining findings are only warnings, so they're printed but don't fail. |
| `ignored: [DL3008]` | `demo/step1-pin-base.Dockerfile` | The apt-pinning warning disappears from the list. |
| Change the clean `Dockerfile` to `FROM ghcr.io/someorg/python:3.12.7` | `Dockerfile` | **DL3026 error:** that registry isn't in `trustedRegistries`. |

> The key is spelled `trustedRegistries` (camelCase). Hadolint v2.12 silently ignores `trusted-registries`.

You can also ignore a rule for a single line with an inline comment:

```dockerfile
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
```

> In the workflow, `failure-threshold` is also set on the action itself. The action passes its own default (`info`) to Hadolint, which would otherwise override the value in the config file.

---

## Run the app (optional)

```powershell
docker build -t hadolint-demo .
docker run --rm -p 5000:5000 hadolint-demo
# http://localhost:5000  -> {"message": "Hello from a Hadolint-approved container!"}
docker exec <container-id> whoami   # -> appuser
```
