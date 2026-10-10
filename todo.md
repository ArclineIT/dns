# arcline-dns — DNS Propagation Checker

Query a domain across global resolvers and diff the results.
Indispensable during DNS migrations — customers see exactly where propagation stands.

## Stack
- Ruby on Rails 8.1, no database
- Web page, JSON and text endpoints, and a rake task for the terminal

## Resolver list (embedded, configurable)
- Cloudflare: 1.1.1.1, 1.0.0.1
- Google: 8.8.8.8, 8.8.4.4
- OpenDNS: 208.67.222.222
- Quad9: 9.9.9.9
- Authoritative nameservers for the queried domain (auto-detected)
- Configurable: `resolvers` parameter or `RESOLVERS` variable

## Features
- [x] Query A, AAAA, CNAME, MX, TXT, NS, SOA record types
- [x] Parallel queries across all resolvers
- [x] Diff mode: highlight resolvers that disagree with the majority
- [x] TTL display per resolver
- [x] Watch: re-query every N seconds (`&watch=30`)
- [x] Color-coded: green = matches majority, red = differs, yellow = no response

## Interface
```
bin/rails 'dns:lookup[example.com,MX]'
RESOLVERS=8.8.8.8,1.1.1.1 bin/rails 'dns:lookup[example.com]'
FORMAT=json bin/rails 'dns:lookup[example.com]'
GET /lookup?domain=example.com&type=MX     (also .json and .txt, &resolvers=, &watch=30)
```

## Output format
```
$ arcline-dns example.com --type A

  domain   example.com
  type     A
  queried  6 resolvers

  resolver            answer          ttl    status
  ─────────────────── ─────────────── ────── ───────
  1.1.1.1 (CF)        203.0.113.42    300s   [OK]
  1.0.0.1 (CF)        203.0.113.42    300s   [OK]
  8.8.8.8 (Google)    203.0.113.42    300s   [OK]
  8.8.4.4 (Google)    203.0.113.42    300s   [OK]
  208.67.222.222      203.0.113.10    300s   [DIFF]
  9.9.9.9 (Quad9)     203.0.113.42    300s   [OK]

  propagation   5/6 resolvers agree
```

## Tasks
- [x] Rails app scaffold
- [x] Embedded resolver list
- [x] Parallel DNS query engine (raw UDP, TCP when truncated)
- [x] Record type formatting (A, AAAA, CNAME, MX, TXT, NS, SOA)
- [x] Diff/majority logic
- [x] Table renderer (web, text, JSON)
- [x] Watch mode
- [x] Authoritative NS auto-detection
- [x] README
- [ ] Show what changed between watch refreshes
- [ ] DNSSEC status of the answer
