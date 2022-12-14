[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Ffluential%2Flitestream-uptime-kuma%2F&count_bg=%2379C83D&title_bg=%23555555&icon=github.svg&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)

## Uptime-Kuma with persistent sqlite database

Run uptime kuma with persisten sqlite database via [litestream](https://litestream.io)

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new/template/UfDasl?referralCode=373)

## Usage

### Build

```
docker build -t litestream-uptime-kuma .
```

### Run
```
docker run --rm -ti -p 3001:3001 -e LITESTREAM_ACCESS_KEY_ID='XXX' -e LITESTREAM_SECRET_ACCESS_KEY='YYY' -e LITESTREAM_BUCKET=uptime-kuma -e LITESTREAM_URL=https://YYY.r2.cloudflarestorage.com  litestream-uptime-kuma
```

## Environment Variables:
  - `UPTIME_KUMA_VERSION`: Kuma version
  - `LITESTREAM_VERSION`: Litestream version
  - `LITESTREAM_ACCESS_KEY_ID`: Storage bucket acces key id
  - `LITESTREAM_SECRET_ACCESS_KEY`: Storage bucket access key
  - `LITESTREAM_BUCKET`: Storage bucket
  - `LITESTREAM_URL`: Storage url endpoint

## TODO
- Use disrtoless image  `gcr.io/distroless/nodejs18-debian11`
- Use `node:slim` - currently some ssl issues
