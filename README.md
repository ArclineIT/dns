# Arcline DNS

DNS propagation checker. It asks several public resolvers, and the domain's
own nameservers, the same question at once and shows which of them disagree,
so you can see exactly where a DNS change stands during a migration.

This was planned as a Go command-line tool and is built instead as a Ruby on
Rails app: a web page, a JSON and plain-text endpoint for scripting, and a
terminal command.

## Use it

In the browser, enter a domain and pick a record type. For scripts:

```sh
curl 'https://dns.arcline.it/lookup.txt?domain=example.com&type=MX'
curl 'https://dns.arcline.it/lookup.json?domain=example.com'
curl 'https://dns.arcline.it/lookup.txt?domain=example.com&resolvers=8.8.8.8,1.1.1.1'
```

From a checkout:

```sh
bin/rails 'dns:lookup[example.com]'
bin/rails 'dns:lookup[example.com,MX]'
RESOLVERS=8.8.8.8,1.1.1.1 bin/rails 'dns:lookup[example.com]'
FORMAT=json bin/rails 'dns:lookup[example.com,TXT]'
```

The terminal command exits 1 unless every resolver agrees.

```
  domain   example.com
  type     A
  queried  6 resolvers

  resolver                  answer        ttl     status
  ────────────────────────  ────────────  ──────  ──────
  1.1.1.1 (Cloudflare)      203.0.113.42  300s    [OK]
  1.0.0.1 (Cloudflare)      203.0.113.42  300s    [OK]
  8.8.8.8 (Google)          203.0.113.42  300s    [OK]
  8.8.4.4 (Google)          203.0.113.42  300s    [OK]
  208.67.222.222 (OpenDNS)  203.0.113.10  300s    [DIFF]
  9.9.9.9 (Quad9)           203.0.113.42  300s    [OK]

  propagation   5/6 resolvers agree
```

Add `&watch=30` to the page address to re-check every 30 seconds.

## What it checks

- **Record types:** A, AAAA, CNAME, MX, TXT, NS, SOA. Names such as
  `_dmarc.example.com` work.
- **Resolvers:** Cloudflare (1.1.1.1, 1.0.0.1), Google (8.8.8.8, 8.8.4.4),
  OpenDNS (208.67.222.222), Quad9 (9.9.9.9), plus the domain's authoritative
  nameservers, which are found automatically. Or name up to 12 of your own.
- **Status:** `OK` matches the majority, `DIFF` gives a different answer, and
  `NONE` did not respond. Resolvers that all report "no such record" agree
  with each other.
- **TTL** per resolver, which is how long a `DIFF` resolver may keep its old
  answer.

Each resolver is queried directly over UDP, falling back to TCP when the
answer is truncated, and all of them are asked in parallel.

## Safety

- The domain must be a public hostname.
- Custom resolvers must be public IP addresses, so the tool cannot be aimed at
  a private network.
- Lookups are limited to 30 a minute per client.

## Requirements

- Ruby 4.0+
- No database

## Setup

```bash
bin/setup --skip-server
bin/rails server          # http://localhost:3000, or PORT if set
```

## Tests

```bash
bin/rails test
bin/rubocop
bin/brakeman
```

The tests do not touch the network: the query engine is tested against a
local UDP server.

## License

MIT. See [LICENSE](LICENSE).
