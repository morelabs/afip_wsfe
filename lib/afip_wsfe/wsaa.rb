module AfipWsfe
  # Authorization class. Handles interactions wiht the WSAA, to provide
  # valid key and signature that will last for a day.
  #
  class Wsaa

    def initialize(url=nil)
      AfipWsfe.environment ||= :test
      @client = Savon.client(
        wsdl:  AfipWsfe::URLS[AfipWsfe.environment][:wsaa],
        namespaces: {
          "xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/",
          "xmlns:ar" => "http://ar.gov.afip.dif.FEV1/"
        },
        log:       AfipWsfe.log?,
        log_level: AfipWsfe.log_level || :debug,
        ssl_verify_mode: :none,
        read_timeout: 90,
        open_timeout: 90,
        headers: {
          "Accept-Encoding" => "gzip, deflate",
          "Connection" => "Keep-Alive"
        },
        convert_request_keys_to: :none
      )

      @cms  = nil
      @performed = false
      @response = nil
    end

    def login
      raise "Archivo de llave privada no encontrado en #{ AfipWsfe.pkey }" unless File.exists?(AfipWsfe.pkey)
      raise "Archivo certificado no encontrado en #{ AfipWsfe.cert }" unless File.exists?(AfipWsfe.cert)
      build_tra
      call_web_service
      parse_response
      status
    end

    def status
      return false unless @performed
      @response.success?
    end

    protected

    def build_tra
      now  = Time.zone.now
      from = now.beginning_of_day.strftime('%FT%T%:z')
      to   = now.end_of_day.strftime('%FT%T%:z')
      id   = now.strftime('%s')

      tra = {
        "header" => {
          "uniqueId"       => id,
          "generationTime" => from,
          "expirationTime" => to
        },
        "service" => "wsfe"
      }.to_xml(root: "loginTicketRequest")

      @cms = `echo '#{ tra }' |
        #{ AfipWsfe.openssl_bin } cms -sign -in /dev/stdin -signer #{ AfipWsfe.cert } -inkey #{ AfipWsfe.pkey } -nodetach -outform der |
        #{ AfipWsfe.openssl_bin } base64 -e`
    end

    def call_web_service
      body = { "ns1:in0" => @cms }
      @response = @client.call :login_cms, message: body
      @performed = true
    end

    def parse_response
      if status
        response_hash = Hash.from_xml @response.body[:login_cms_response][:login_cms_return]
        token = response_hash["loginTicketResponse"]["credentials"]["token"]
        sign  = response_hash["loginTicketResponse"]["credentials"]["sign"]
        write_yaml(token, sign)
      end
    end

    def write_yaml(token, sign)
      filename = "/tmp/bravo_#{ AfipWsfe.cuit }_#{ Time.zone.today.strftime('%Y_%m_%d') }.yml"
      content = {
        token: token,
        sign: sign
      }
      File.open(filename, 'w') { |f|
        f.write content.to_yaml
      }
    end
  end
end
