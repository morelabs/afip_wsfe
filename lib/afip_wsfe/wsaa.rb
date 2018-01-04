module AfipWsfe
  # Authorization class. Handles interactions wiht the WSAA, to provide
  # valid key and signature that will last for a day.
  #
  class Wsaa
    # Main method for authentication and authorization.
    # When successful, produces the yaml file with auth data.

    def initialize(url=nil)
      @url  = url || AfipWsfe::URLS[AfipWsfe.environment][:wsaa]
      @tra  = nil
      @cms  = nil
      @req  = nil

      @token = nil
      @sign  = nil
    end

    def self.login
      build_tra
      call_web_service
      write_yaml
    end

    protected

    # Builds the xml for the 'Ticket de Requerimiento de Acceso'
    def self.build_tra
      @now = (Time.now) - 120
      @from = @now.strftime('%FT%T%:z')
      @to   = (@now + ((12*60*60))).strftime('%FT%T%:z')
      @id   = @now.strftime('%s')

      @tra = {
        "header" => {
          "uniqueId"       => @id,
          "generationTime" => @from,
          "expirationTime" => @to
        },
        "service" => "wsfe"
      }.to_xml(root: "loginTicketRequest")

      build_cms
      build_request
    end

    # Builds the CMS
    def self.build_cms
      @cms = `echo '#{ @tra }' |
        #{ AfipWsfe.openssl_bin } cms -sign -in /dev/stdin -signer #{ AfipWsfe.cert } -inkey #{ AfipWsfe.pkey } -nodetach -outform der |
        #{ AfipWsfe.openssl_bin } base64 -e`
    end

    # Builds the request
    def self.build_request
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send("SOAP-ENV:Envelope", "xmlns:SOAP-ENV" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:ns1" => "http://wsaa.view.sua.dvadac.desein.afip.gov") do
          xml.send("SOAP-ENV:Body") do
            xml.send("ns1:loginCms") do
              xml.send("ns1:in0", @cms)
            end
          end
        end
      end
      @req = builder.to_xml
    end

    # Calls the WSAA
    def self.call_web_service
      response = `echo '#{ @req }' | curl -k -s -H 'Content-Type: application/soap+xml; action=""' -d @- #{ @url }`
      response = CGI::unescapeHTML(response)
      @token   = response.scan(/\<token\>(.+)\<\/token\>/).first.first
      @sign    = response.scan(/\<sign\>(.+)\<\/sign\>/).first.first
    end

    # Writes the token and signature to a YAML file in the /tmp directory
    def self.write_yaml(certs)
      filename = "/tmp/bravo_#{ AfipWsfe.cuit }_#{ Time.zone.today.strftime('%Y_%m_%d') }.yml"
      content = {
        token: @token,
        sign: @sign
      }
      File.open(filename, 'w') { |f|
        f.write content.to_yaml
      }
    end

  end
end
