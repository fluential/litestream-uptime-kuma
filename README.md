# Litestream Uptime Kuma

Run [Uptime Kuma](https://github.com/louislam/uptime-kuma) with persistent SQLite database via [Litestream](https://litestream.io) replication to S3-compatible storage.

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new/template/UfDasl?referralCode=373)

## How it works

Litestream continuously replicates the Uptime Kuma SQLite database to an S3-compatible bucket (Cloudflare R2, AWS S3, MinIO, etc). On container start, the database is restored from the replica. This gives you persistent data without a managed database.

Litestream v0.5.x uses the LTX format with hierarchical compaction, dramatically reducing S3 operations compared to the old WAL segment approach.

## Build

```
docker build -t litestream-uptime-kuma .
```

## Run

```
docker run --rm -p 3001:3001 \
  -e LITESTREAM_ACCESS_KEY_ID='XXX' \
  -e LITESTREAM_SECRET_ACCESS_KEY='YYY' \
  -e LITESTREAM_BUCKET=uptime-kuma \
  -e LITESTREAM_URL=https://ACCOUNT.r2.cloudflarestorage.com \
  litestream-uptime-kuma
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LITESTREAM_ACCESS_KEY_ID` | *required* | S3/R2 access key ID |
| `LITESTREAM_SECRET_ACCESS_KEY` | *required* | S3/R2 secret access key |
| `LITESTREAM_BUCKET` | `uptime-kuma` | Storage bucket name |
| `LITESTREAM_URL` | *required* | S3 endpoint URL |
| `LITESTREAM_PATH` | `uptime-kuma-db` | Path within bucket |
| `LITESTREAM_SYNC_INTERVAL` | `30s` | How often to sync to S3 |
| `LITESTREAM_SNAPSHOT_INTERVAL` | `1h` | How often to take full snapshots |
| `DATA_DIR` | `/app/data` | Database directory inside container |

## Running without Litestream

Omit `LITESTREAM_URL` and the container runs Uptime Kuma standalone (no replication). Useful for local development.

## Versions

- Uptime Kuma: 2.1.3
- Litestream: 0.5.9
- Node.js: 22 (slim)
