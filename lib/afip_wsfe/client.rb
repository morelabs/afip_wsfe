module AfipWsfe
  class Client
    def initialize(authenticate=true)
      AfipWsfe.environment ||= :test
      @auth = authenticate ? AfipWsfe.auth_hash : {}
    end

    def call_endpoint(endpoint, savon_method, params={})
      return_key = endpoint == :wsaa ? :"#{savon_method}_return" : :"#{savon_method}_result"
      
      result = Savon.client(
        log: AfipWsfe.log?,
        log_level: AfipWsfe.log_level || :debug,
        wsdl: "#{AfipWsfe::URLS[AfipWsfe.environment][endpoint]}?wsdl",
        convert_request_keys_to: :camelcase
      ).call(savon_method, message: params.merge(@auth))

      response = result.body[:"#{savon_method}_response"][return_key]
      Hash.from_xml response if endpoint == :wsaa

      [result.success?, response]
    end
  end
end
