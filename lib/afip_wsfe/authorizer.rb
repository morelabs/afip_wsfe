module AfipWsfe
  class Authorizer
    attr_reader :pkey, :cert

    def initialize
      @pkey = AfipWsfe.pkey
      @cert = AfipWsfe.cert
    end
  end
end