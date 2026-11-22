# Daily production health pass

The runbook of the daily Shiori health routine: once a day, analyse the last 24 hours of costs,
performance, user activity and monitoring in production, fix what is broken, push the fixes to
`main` and watch CI. Any change to the routine is made in this file and committed; the scheduled
prompt only needs to point here.

The final report is written in **French**.

## Scope

|                 |                                                                           |
| --------------- | ------------------------------------------------------------------------- |
| Repository      | `/workspace/shiori` (pi6) or `/Users/thibaut/Code/shiori` (Mac)           |
| GCP project     | `shiori-polyforms`, region `europe-west3`                                 |
| Backend         | Cloud Function gen2 `shiori-server`, scale-to-zero                        |
| Request logs    | `resource.type="cloud_run_revision"`                                      |
| Production host | https://shiori-server-hvrhl6ox5q-ey.a.run.app                             |
| Billing export  | `vinarium-prod.billing_export.gcp_billing_export_v1_01B9B2_D51D23_1EF14D` |

**Error logs are out of scope.** Every `warn` / `error` is reported to Sentry and handled by the
separate 6-hourly `sentry-autofix-6h` routine. Never triage error logs or Sentry issues here.
**App Store / TestFlight is out of scope.**

## Ground rules

- Read [CLAUDE.md](../CLAUDE.md) first and follow it: `bun` only, verification before commit,
  cost rules, API evolution rules, logging rules.
- Work inline: never launch sub-agents.
- Other Claude sessions may be editing this checkout: commit only the files you changed with an
  explicit pathspec; never stash, reset, switch branches, amend or force-push; recheck `git log`
  right before committing.
- Never read or print API keys or secrets.
- Aggregate figures only: never names, emails, user ids or IP addresses in the report.
- Scratch files go in `/tmp/shiori-health` (`mkdir -p /tmp/shiori-health`), never in the
  repository.

## 0. Preconditions

GCP access goes through the read-only service account
`shiori-observer@shiori-polyforms.iam.gserviceaccount.com`, in its own gcloud configuration so the
user's account is never touched: prefix **every** `gcloud` / `bq` command with
`CLOUDSDK_CONFIG=$HOME/.config/shiori-observer/gcloud`. This account only reads: never try to
write anything to GCP with it.

```bash
CLOUDSDK_CONFIG=$HOME/.config/shiori-observer/gcloud gcloud auth print-access-token >/dev/null && echo ok
git -C /workspace/shiori pull --ff-only
```

- If the check fails, never fall back to the user's own gcloud login and never run
  `gcloud auth login`: do the steps that need no GCP (CI, `/app-config`) and open the report with
  « Le compte de lecture shiori-observer ne répond pas » followed by the error.
- If `pull --ff-only` is refused, work on what is there and say so.

## 1. Costs

Cost plus credits per `DATE(usage_start_time, "Europe/Paris")` and per `service.description` /
`sku.description` over the last 8 days, filtered on `project.id = "shiori-polyforms"`:

```bash
bq query --project_id=shiori-polyforms --use_legacy_sql=false --format=prettyjson --max_rows=500 '
SELECT DATE(usage_start_time,"Europe/Paris") d, service.description s, sku.description k,
  ROUND(SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)), 3) net
FROM `vinarium-prod.billing_export.gcp_billing_export_v1_01B9B2_D51D23_1EF14D`
WHERE project.id = "shiori-polyforms"
  AND DATE(usage_start_time,"Europe/Paris") >= DATE_SUB(CURRENT_DATE("Europe/Paris"), INTERVAL 8 DAY)
GROUP BY 1,2,3 HAVING ABS(net) > 0.001 ORDER BY 1,2,3'
```

`bq` prints a urllib3 warning before the JSON: strip lines that are not JSON before `jq`. The
export lags several hours: yesterday may be partial, say so.

- Flag any service whose yesterday cost is > 2× its 7-day daily average, Gemini API > €3 in a
  day, or any new SKU.
- Gemini: the SKU "Generate content search query gemini 3 paid one" is grounded search
  (≈ €0.0123 each; 5,000 free per month). Trace a spike with
  `gcloud logging read --project=shiori-polyforms ... 'textPayload:" searches"'` (each call logs
  `[scan] ℹ <step>: N in, N out, N thinking, N searches`; logged searches undercount the bill
  ~4×), grouped by step and hour; `httpRequest.userAgent` / `remoteIp` on `/graphql` tell if one
  device caused it.
- Gemini is prepaid: if calls answer 402 "prepayment credits are depleted", it is critical —
  report it at the top (only the user can top up).

## 2. Performance

- From the `/graphql` request logs of the last 24 h: p50 / p95 / p99 of `httpRequest.latency`,
  5xx rate, slowest hours, compared with the previous 24 h.
- The `[graphql] operation served` lines (`jsonPayload`: `operation`, `type`, `durationMs`,
  `reads`, `debugBuild`) give the slowest and most expensive operations.
- Cloud Monitoring with the observer token: `run.googleapis.com/request_latencies`,
  `container/instance_count` (per `state`), `container/startup_latencies` (`ALIGN_DELTA` gives the
  number of cold starts and their mean), `container/memory/utilizations`, filtered on
  `resource.labels.service_name="shiori-server"`.
- Flag p95 > 2 s, a regression > 50 %, memory close to the limit, or frequent cold starts. The
  user declined a warm instance (`min_instance_count`): never propose it again.
- Firestore usage (`firestore.googleapis.com/document/read_count` etc.) when a cost or latency
  spike points there. Production data may be read (read-only) to explain a spike; never copy
  readers' personal data into the report.

## 2b. User activity

- **Users**: Firestore document `admin-metrics/current` (`totalUsers`, `newUsers` and
  `newPremium` this month, `premium.total`, `refreshedAt`); `sessions.days` carries the GA4
  sessions per day. Compare with the previous report in the session (the routine reuses one
  session every day) and say how many users arrived since; on a first run, give the month's count.
- **Per day over 8 days**: GraphQL requests, mutations (from `operation served`), distinct devices
  (approximated by distinct `remoteIp`), app builds seen (first token of `httpRequest.userAgent`),
  5xx count. `Shiori/1` with `debugBuild: true` is a build run from Xcode: development, not
  readers — give the figures without it as well.
- **Content added** in the last 24 h and 7 days: count aggregation on `books`, field `addedAt`.
- Say plainly whether activity is rising, stable or falling, and whether a drop looks like an
  outage (5xx, failed jobs) or just usage. Bursts of hundreds of requests a minute apart from one
  build, often on a simulator's Darwin version, are automated runs (captures, e2e): say so rather
  than counting them.

```bash
export CLOUDSDK_CONFIG=$HOME/.config/shiori-observer/gcloud
TOK=$(gcloud auth print-access-token)
FS='https://firestore.googleapis.com/v1/projects/shiori-polyforms/databases/(default)/documents'
curl -s -H "Authorization: Bearer $TOK" "$FS/admin-metrics/current" | jq -c '.fields |
  {totalUsers, newUsers, newPremium, premium: .premium.mapValue.fields.total, refreshedAt,
   sessions: (.sessions.mapValue.fields.days.arrayValue.values // [] |
     map(.mapValue.fields | [.day.stringValue, .sessions.integerValue]) | .[-8:])}'
for d in 1 7; do since=$(date -u -d "$d days ago" +%Y-%m-%dT%H:%M:%SZ)
  curl -s -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -X POST \
    "${FS}:runAggregationQuery" -d "{\"structuredAggregationQuery\":{\"structuredQuery\":{
      \"from\":[{\"collectionId\":\"books\"}],
      \"where\":{\"fieldFilter\":{\"field\":{\"fieldPath\":\"addedAt\"},\"op\":\"GREATER_THAN_OR_EQUAL\",
      \"value\":{\"timestampValue\":\"$since\"}}}},\"aggregations\":[{\"alias\":\"n\",\"count\":{}}]}}" |
    jq -c "{days:$d, n: .[0].result.aggregateFields.n.integerValue}"
done
gcloud logging read --project=shiori-polyforms --freshness=8d \
  'resource.type="cloud_run_revision" AND httpRequest.requestUrl:"/graphql"' \
  --format=json --limit=50000 > /tmp/shiori-health/gql8.json
gcloud logging read --project=shiori-polyforms --freshness=8d \
  'resource.type="cloud_run_revision" AND jsonPayload.message="[graphql] operation served"' \
  --format=json --limit=50000 > /tmp/shiori-health/ops8.json
```

Keep the Firestore URL single-quoted (parentheses), and write `${FS}:runAggregationQuery` with
braces. If the observer account is refused on Firestore, say so and give the activity from the
request logs alone.

## 3. Monitoring

### CI

`gh run list --repo moifort/shiori --limit 30 --json databaseId,name,headSha,status,conclusion,createdAt`:
any failed run on `main` in the last 24 h, Deploy above all (production only ships through it).
Check the last Deploy succeeded, including its "Run Firestore migrations" step
(`gh run view <id> --json jobs`).

### Cloud Scheduler — every job, never one summary line

`gcloud scheduler jobs list --project=shiori-polyforms --location=europe-west3 --format=json`
gives each job's schedule, state, last attempt time and status (`.status.code`, 0 = OK). Then its
runs over 8 days from the request logs:

```bash
gcloud logging read --project=shiori-polyforms --freshness=8d \
  'resource.type="cloud_run_revision" AND httpRequest.userAgent:"Google-Cloud-Scheduler"' --format=json |
  jq -r '.[] | [.timestamp, .httpRequest.requestUrl, .httpRequest.status, .httpRequest.latency] | @tsv' | sort
```

Compare latencies as numbers (`rtrimstr("s") | tonumber`), never as strings. For each job:
number of runs against what its schedule implies, statuses, latencies. Flag a paused job, any
non-200, a run near the job's `attemptDeadline` or the function's timeout, a missed run, or a
latency that doubled. `generate-discoveries` only runs on the 1st and 2nd of the month.

### Firestore writes per job — does it add data or run for nothing?

Every `/admin/*` call logs one `[job] job served` line (`server/plugins/04-job-metrics.ts`) with
the job, its status and duration, the documents it read (`docReads`, `queryDocs`, `reads`) and
the documents it wrote: `creates`, `sets` (created or overwritten), `updates`, `deletes` and their
sum `writes`. A write is counted when queued, so a retried transaction counts once per attempt.

```bash
gcloud logging read --project=shiori-polyforms --freshness=8d \
  'resource.type="cloud_run_revision" AND jsonPayload.message="[job] job served"' \
  --format=json --limit=5000 |
  jq -r '.[] | [.timestamp[:10], .jsonPayload.job, .jsonPayload.status, .jsonPayload.durationMs,
    .jsonPayload.reads, .jsonPayload.creates, .jsonPayload.sets, .jsonPayload.updates,
    .jsonPayload.deletes, .jsonPayload.writes] | @tsv' | sort
```

For each job, over 24 h and 8 days: runs, runs with zero writes, total creates / sets / updates /
deletes, and reads per run. Say for each job whether it **adds data** (creates, sets), **only
maintains** (updates, deletes) or **runs for nothing** (no write at all). Flag:

- a job with no write over 8 days whose purpose is to write (a sync, a watch, a refresh): it is
  probably broken or targets nobody;
- a job that reads a lot per run and writes nothing, run after run: reads paid for nothing, a
  candidate for an early exit or a lower cadence (propose, do not apply);
- a job whose writes jumped or fell to zero from one day to the next;
- writes on every run of a job that should write only when something changed (the hourly
  Découvrir passes write their state only when it changed): it rewrites unchanged data.

The lines exist from the deploy that added them (2026-11-22). Before that, or if they are
missing, fall back on `firestore.googleapis.com/document/write_count` aligned per minute
(`ALIGN_DELTA`, 60 s) around each scheduler run's timestamp, and say the figure is approximate
(user mutations in the same minute add to it).

### `/app-config`

`curl -s -o /dev/null -w '%{http_code}' https://shiori-server-hvrhl6ox5q-ey.a.run.app/app-config`
answers 200.

## 4. Fix

For each real problem with a clear cause in the code:

- Fix it following CLAUDE.md (domain layout, logger, no `console.*`, deprecate rather than remove
  GraphQL fields).
- Verify: `bunx nitro prepare && bunx tsc --noEmit`, `bun test` run per suffix
  (`bun test .unit.test`, `bun test .int.test`, `bun test .feat.test` separately — `mock.module`
  leaks across files), `bunx biome check`, `bun run schema:check` if the schema changed.
- Commit (conventional commits, English, explicit pathspec, without asking for approval) and push
  directly to `main`: the user authorised it for this routine.
- After the push, watch every CI run for the pushed commit (`gh run list` filtered on `headSha`,
  then `gh run watch <id> --exit-status`) until all are finished, Deploy included; on failure read
  `gh run view <id> --log-failed`, fix forward with a new commit, push, watch again.
- Never touch `CHANGELOG.md` / `CHANGELOG.fr.md`. Never `terraform apply` or deploy from the
  machine. Never run migrations by hand.
- Do **not** apply, only propose in the report: anything that changes what readers see or can do
  (disabling a feature, lowering a quota, changing a model), any infrastructure / Terraform /
  secret change, anything whose cause is unclear, and any change that would raise paid API calls
  (state its cost per CLAUDE.md).

## 5. Report (in French, short)

Start with the verdict in one line (RAS / problèmes corrigés / action requise de votre part).
Then four sections, each with findings in plain words:

- **Coûts** — yesterday's total and per service, vs the 7-day average.
- **Performances** — p50 / p95, 5xx rate, instances, cold starts.
- **Activité** — users and new users since the previous report, premium, sessions, requests,
  devices, builds, books added, trend.
- **Monitoring** — CI, Deploy, and a table of every scheduler job: schedule, state, last run,
  status, runs over 8 days, latencies, and **Firestore writes** (creates / sets / updates /
  deletes over 24 h and 8 days, runs with no write) with a verdict per job: adds data, only
  maintains, or runs for nothing.

Then « Corrigé » (commit hashes, CI result per workflow) and « À décider » (proposals that need
the user). If nothing is wrong, say so in a few lines.

## Machine notes

On pi6 (Linux arm64, HolyClaude container):

- GNU `date`: `date -u -d '1 day ago' …`, never the BSD `date -v` form.
- `bun` lives in `/opt/outils/bun/bin` and its `bunx` link is broken: use `bun x` in its place.
- There is no Xcode: never change iOS code; put any iOS fix in « À décider ».
- Push over HTTPS to `origin` (gh credentials are set up, with the `workflow` scope).
