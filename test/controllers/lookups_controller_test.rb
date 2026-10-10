require "test_helper"

# "domain" is also a url_for option, so it has to travel in params:.
class LookupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @query = FakeQuery.new do |server, name, type|
      next [ "ns1.host.test" ] if type == "NS" && name == "example.com"
      next [ "203.1.113.1" ] if name == "ns1.host.test"
      next [] if type == "NS"
      server == "9.9.9.9" ? [ "203.1.113.10" ] : [ "203.1.113.42" ]
    end
  end

  test "the home page has the form with every record type" do
    get root_path

    assert_response :success
    assert_select "form[action='/lookup'][method=get] select[name=type] option", DnsQuery::TYPES.size
  end

  test "asks the public resolvers and the domain's own nameservers" do
    lookup domain: "https://Example.com/"

    assert_response :success
    assert_select "h1", /example.com\s+A/
    assert_select "tbody tr", 7
    assert_select ".cell-note", text: "ns1.host.test · authoritative"
    assert_select ".status-badge--crit", text: "diff", count: 1
    assert_select ".lead", "6/7 resolvers agree."
  end

  test "uses only the given resolvers when some are listed" do
    lookup domain: "example.com", type: "mx", resolvers: "8.8.8.8, 9.9.9.9"

    assert_select "h1", /MX/
    assert_select "tbody tr", 2
    assert_select "input[name=resolvers][value='8.8.8.8, 9.9.9.9']"
  end

  test "an unknown type falls back to A, and watch refreshes within limits" do
    lookup domain: "example.com", type: "AXFR", watch: 2

    assert_select "h1", /example.com\s+A/
    assert_select "meta[http-equiv=refresh][content='10']"
  end

  test "answers in JSON and text" do
    lookup domain: "example.com", resolvers: "8.8.8.8", format: :json
    assert_equal [ "example.com", "A", true ], response.parsed_body.values_at("domain", "type", "propagated")

    lookup domain: "example.com", resolvers: "8.8.8.8", format: :text
    assert_includes response.body, "  8.8.8.8 (Google)  203.1.113.42  300s    [OK]"
  end

  test "bad domains and private resolvers are refused before any query is sent" do
    lookup domain: "localhost"
    assert_redirected_to root_path
    assert_equal "localhost is not a valid domain name.", flash[:alert]

    lookup domain: "example.com", resolvers: "192.168.1.1"
    assert_equal "192.168.1.1 is not a public IP address.", flash[:alert]

    lookup domain: "example.com", resolvers: "10.0.0.1", format: :json
    assert_response :unprocessable_entity
    assert_equal 0, @query.asked.size
  end

  private
    def lookup(format: nil, **params)
      stub_method(DnsQuery, :call, ->(*args, **options) { @query.call(*args, **options) }) do
        get lookup_path(format: format, params: params)
      end
    end
end
