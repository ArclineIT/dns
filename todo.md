# arcline-dns — DNS Propagation Checker

Query a domain across global resolvers and diff the results.
Indispensable during DNS migrations — customers see exactly where propagation stands.

## Stack
- Language: Go
- Distribution: single static binary
- No runtime dependencies

## Resolver list (embedded, configurable)
- Cloudflare: 1.1.1.1, 1.0.0.1
- Google: 8.8.8.8, 8.8.4.4
- OpenDNS: 208.67.222.222
- Quad9: 9.9.9.9
- Authoritative nameservers for the queried domain (auto-detected)
- Configurable: --resolvers flag or .arcline-dns.yaml

## Features
- [ ] Query A, AAAA, CNAME, MX, TXT, NS, SOA record types
- [ ] Parallel queries across all resolvers
- [ ] Diff mode: highlight resolvers that disagree with the majority
- [ ] TTL display per resolver
- [ ] --watch N: re-query every N seconds, show changes live
- [ ] Color-coded: green = matches majority, red = differs, yellow = no response

## CLI interface
```
arcline-dns example.com
arcline-dns example.com --type MX
arcline-dns example.com --type A --watch 30
arcline-dns example.com --resolvers 8.8.8.8,1.1.1.1
arcline-dns example.com --json
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
- [ ] Project scaffold
- [ ] Embedded resolver list
- [ ] Parallel DNS query engine (net package, raw UDP)
- [ ] Record type parser (A, AAAA, CNAME, MX, TXT, NS, SOA)
- [ ] Diff/majority logic
- [ ] Table renderer (terminal + JSON)
- [ ] --watch mode with delta display
- [ ] Authoritative NS auto-detection
- [ ] Cross-compile Makefile
- [ ] README
