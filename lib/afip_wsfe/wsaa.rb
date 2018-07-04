module AfipWsfe
  # Authorization class. Handles interactions wiht the WSAA, to provide
  # valid key and signature that will last for a day.
  #
  class Wsaa

    def initialize(url=nil)
      @client = AfipWsfe::Client.new(false)
      @endpoint = :wsaa
      @response = nil
      @status = false
    end

    def login
      raise "Ruta del archivo de llave privada no declarado" unless AfipWsfe.pkey.present?
      raise "Ruta del archivo certificado no declarado" unless AfipWsfe.cert.present?
      raise "Archivo de llave privada no encontrado en #{ AfipWsfe.pkey }" unless File.exists?(AfipWsfe.pkey)
      raise "Archivo certificado no encontrado en #{ AfipWsfe.cert }" unless File.exists?(AfipWsfe.cert)
      @status, @response = @client.call_endpoint @endpoint, :login_cms, {in0: build_tra}
      parse_response
      @status
    end

    private

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

      pkcs7 = OpenSSL::PKCS7.sign(cert, key, tra)
      OpenSSL::PKCS7.write_smime(pkcs7).lines[5..-2].join()
    end

    def parse_response
      write_yaml(@response["loginTicketResponse"]["credentials"])
    end

    def write_yaml(credentials)
      filename = AuthData.todays_data_file_name
      content = {
        token: credentials["token"],
        sign: credentials["sign"]
      }
      File.open(filename, 'w') { |f|
        f.write content.to_yaml
      }
    end

    def cert
      OpenSSL::X509::Certificate.new(File.read(AfipWsfe.cert))
    end

    def key
      OpenSSL::PKey::RSA.new(File.read(AfipWsfe.pkey))
    end
  end
end
