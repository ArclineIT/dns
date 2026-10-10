# A DNS server to ask, with the label shown beside it.
class Resolver < Data.define(:address, :label, :authoritative)
  PUBLIC = [
    [ "1.1.1.1", "Cloudflare" ], [ "1.0.0.1", "Cloudflare" ], [ "8.8.8.8", "Google" ], [ "8.8.4.4", "Google" ],
    [ "208.67.222.222", "OpenDNS" ], [ "9.9.9.9", "Quad9" ]
  ].freeze
  MAX_CUSTOM = 12

  Invalid = Class.new(StandardError)

  def self.public_list
    PUBLIC.map { |address, label| new(address: address, label: label, authoritative: false) }
  end

  # From a comma-separated list of addresses. Only public addresses are allowed,
  # so the tool cannot be used to probe a private network.
  def self.parse_list(input)
    addresses = input.to_s.split(/[\s,]+/).compact_blank.uniq
    raise Invalid, "List at most #{MAX_CUSTOM} resolvers." if addresses.size > MAX_CUSTOM

    addresses.map do |address|
      raise Invalid, "#{address.truncate(45)} is not a public IP address." unless PublicAddress.public?(address)
      new(address: address, label: PUBLIC.to_h[address], authoritative: false)
    end
  end

  def to_s
    label ? "#{address} (#{label})" : address
  end
end
