# arcline-dns

DNS propagation checker. Queries a domain across multiple global resolvers in parallel and diffs the results — shows exactly where propagation stands during a DNS migration.

## Status

Planned. Not yet started.

## Stack

- Go — single static binary, no runtime dependencies
- Embedded resolver list (Cloudflare, Google, OpenDNS, Quad9, authoritative NS)

## Usage

```sh
arcline-dns example.com
arcline-dns example.com --type MX
arcline-dns example.com --type A --watch 30
arcline-dns example.com --resolvers 8.8.8.8,1.1.1.1
arcline-dns example.com --json
```

## Features

- Parallel queries across all resolvers
- Supports A, AAAA, CNAME, MX, TXT, NS, SOA
- Diff mode: highlights resolvers that disagree with the majority
- TTL per resolver
- `--watch` mode: re-queries on an interval, shows changes live
- Color-coded output: green = agrees, red = differs, yellow = no response

See [todo.md](todo.md) for the full task list and output format spec.

## License

MIT — see [LICENSE](LICENSE).
