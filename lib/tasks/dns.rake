namespace :dns do
  desc "Check propagation from the terminal: bin/rails 'dns:lookup[example.com,MX]' (RESOLVERS=8.8.8.8,1.1.1.1 FORMAT=json)"
  task :lookup, [ :domain, :type ] => :environment do |_task, args|
    domain = DomainName.parse(args[:domain])
    type = (args[:type] || "A").upcase
    abort "unknown record type #{type}; use one of #{DnsQuery::TYPES.keys.join(', ')}" unless DnsQuery::TYPES.key?(type)

    resolvers = ENV["RESOLVERS"].present? ? Resolver.parse_list(ENV["RESOLVERS"]) : Resolver.public_list + AuthoritativeServers.new.call(domain)
    result = Propagation.call(domain, type, resolvers: resolvers)
    puts ENV["FORMAT"] == "json" ? JSON.pretty_generate(result.as_json) : result.to_text(color: $stdout.tty?)
    exit 1 unless result.propagated?
  rescue DomainName::Invalid, Resolver::Invalid => e
    abort e.message
  end
end
