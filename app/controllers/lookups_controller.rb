class LookupsController < ApplicationController
  WATCH_RANGE = 10..3600

  rate_limit to: 30, within: 1.minute, only: :show, with: -> { render plain: "Too many lookups. Try again in a minute.\n", status: :too_many_requests }

  def new
  end

  # GET /lookup?domain=example.com&type=MX, also as .json and .txt.
  def show
    @domain = DomainName.parse(params[:domain])
    @type = params[:type].to_s.upcase.presence_in(DnsQuery::TYPES.keys) || "A"
    @custom = params[:resolvers].to_s.strip.presence
    @result = Propagation.call(@domain, @type, resolvers: resolvers)
    @watch = params[:watch].to_i.clamp(WATCH_RANGE) if params[:watch].present?

    respond_to do |format|
      format.html
      format.json { render json: @result }
      format.text { render plain: @result.to_text }
    end
  rescue DomainName::Invalid, Resolver::Invalid => e
    respond_to do |format|
      format.html { redirect_to root_path, alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
      format.text { render plain: "#{e.message}\n", status: :unprocessable_entity }
    end
  end

  private
    # The given resolvers, or the public ones plus the domain's own nameservers.
    def resolvers
      return Resolver.parse_list(@custom) if @custom

      Resolver.public_list + AuthoritativeServers.new.call(@domain)
    end
end
