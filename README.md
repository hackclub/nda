# nda

a proper nda system for Hack Clubbers, with a public API for checking if a user has signed the nda. this carries all the same legal weight as the previous nda, but is more privacy-conscious, easier to use, less prone to random bugs, and 1000x more open source.

## the stack

- ruby (3.4.10) on rails 8.1 baby!
- [docker hardened images](https://docs.docker.com/dhi/)
- postgresql 18
- vite with bun
- [SpaceXAI Speech to Text](https://docs.x.ai/developers/model-capabilities/audio/speech-to-text) with zero data retention
- cloudflare r2 thats encrypted with SSE-C
- swag

## local dev

copy the `.env.example` to `.env` and fill in the Hack Club Auth and xAI credentials. in Hack Club Auth, register this callback:

```text
http://localhost:3000/auth/hack_club/callback
```

then start the rails, vite, and postgresql 18 services:

```sh
docker compose up --build
```

visit `http://localhost:3000`. anylocal uploads are stored in the `uploads` docker volume.

## admin

u can set `ADMIN_SLACK_IDS` to a comma-separated list of Slack IDs to seed them. the dash at `/admin` shows fun tools for you to keep the system running smoothly

## public api

you can pull someones nda status via this endpoint:

```http
GET /api/v1/nda_status/U0123ABCDEF
```
