# Project badges

The workflow refreshes badges hourly and supports manual Actions runs. The canonical updater is `scripts/update-project-badges.sh`; the local `project2/update-project-badges.sh` entry point invokes it.

Download badges retain the original accumulated repository-clone metric and historical totals (LocalAI 505 and ComAI 248 as of September 30, 2026). They are not release-asset download counts or unique-user counts. GitHub exposes rolling 14-day clone statistics, so the script adds a window only after at least 14 days since its last successful addition. Missed windows cannot be recovered by this method.

Release and star updates, and commits to mirassets, use the built-in Actions token. Reading clone traffic for the source repositories requires access to their traffic statistics. For automatic count increases, configure the optional `BADGE_STATS_TOKEN` Actions secret in mirassets with read access to traffic statistics for all three source repositories (fine-grained token with Metadata read and Administration read). The token is used only for traffic reads; the built-in token still performs badge pushes. Local runs can use the existing authenticated gh account or `GH_STATS_TOKEN`.

When clone traffic is inaccessible or invalid, the updater preserves both the saved total and its last-success timestamp. It never resets an existing total to zero. Release/star API failures stop the run; clean checkouts are required, concurrent Actions runs are serialized, and unchanged data creates no commit.

Local vLLM uses the same accumulated clone metric starting at zero when tracking was enabled. Its badge says **Clones** to distinguish this approximate metric from release-asset downloads. A token without access to its traffic data leaves the saved total unchanged until access is granted.
