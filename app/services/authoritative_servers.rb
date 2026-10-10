require "resolv"

# Finds the nameservers that are authoritative for a name: the NS records of the
# closest enclosing zone, each resolved to an address.
class AuthoritativeServers
  LIMIT = 6

  def initialize(server: Resolver::PUBLIC.first.first, query: DnsQuery)
    @server = server
    @query = query
  end

  def call(name)
    labels = name.split(".")

    # Walk up from the name itself: www.example.com, example.com, com.
    (0..labels.size - 2).each do |skip|
      zone = labels.drop(skip).join(".")
      hosts = @query.call(@server, zone, "NS").records
      next if hosts.empty?

      return hosts.first(LIMIT).filter_map do |host|
        address = @query.call(@server, host, "A").records.first
        Resolver.new(address: address, label: host, authoritative: true) if address && PublicAddress.public?(address)
      end
    end
    []
  end
end
