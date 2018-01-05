module AfipWsfe
  class Bill
    attr_reader :client, :base_imp, :total
    attr_accessor :net, :doc_num, :iva_cond, :documento, :concepto, :moneda,
                  :due_date, :fch_serv_desde, :fch_serv_hasta, :fch_emision,
                  :body, :response, :ivas, :nro_comprobante

    def initialize(attrs = {})
      AfipWsfe.environment ||= :test
      AfipWsfe::AuthData.fetch

      @client = Savon.client(
        wsdl:  AfipWsfe::URLS[AfipWsfe.environment][:wsfe],
        namespaces: {
          "xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/",
          "xmlns:ar" => "http://ar.gov.afip.dif.FEV1/"
        },
        log:       AfipWsfe.log?,
        log_level: AfipWsfe.log_level || :debug,
        ssl_cert_key_file: AfipWsfe.pkey,
        ssl_cert_file:     AfipWsfe.cert,
        ssl_verify_mode: :none,
        read_timeout: 90,
        open_timeout: 90,
        headers: {
          "Accept-Encoding" => "gzip, deflate",
          "Connection" => "Keep-Alive"
        }
      )

      @body           = {"Auth" => AfipWsfe.auth_hash}
      @net            = attrs[:net] || 0
      self.documento  = attrs[:documento] || AfipWsfe.default_documento
      self.moneda     = attrs[:moneda]    || AfipWsfe.default_moneda
      self.iva_cond   = attrs[:iva_cond]  || :responsable_monotributo
      self.concepto   = attrs[:concepto]  || AfipWsfe.default_concepto
      self.ivas       = attrs[:ivas]      || Array.new # [ 1, 100.00, 10.50 ], [ 2, 100.00, 21.00 ] 
    end

    def cbte_type
      AfipWsfe::BILL_TYPE[AfipWsfe.own_iva_cond][iva_cond] || raise(NullOrInvalidAttribute.new, "Please choose a valid document type.")
    end

    def concept
      AfipWsfe::CONCEPTOS[concepto] || raise(NullOrInvalidAttribute.new, "Please choose a valid concept.")
    end

    def document
      AfipWsfe::DOCUMENTOS[documento] || raise(NullOrInvalidAttribute.new, "Please choose a valid document.")
    end

    def currency
      raise(NullOrInvalidAttribute.new, "Please choose a valid currency.") unless AfipWsfe::MONEDAS[moneda]
      AfipWsfe::MONEDAS[moneda][:codigo]
    end

    def exchange_rate
      return 1 if moneda == :peso
      response = client.call :fe_param_get_cotizacion do
        body.merge!({"MonId" => AfipWsfe::MONEDAS[moneda][:codigo]})
      end
      response.to_hash[:fe_param_get_cotizacion_response][:fe_param_get_cotizacion_result][:result_get][:mon_cotiz].to_f
    end

    def total
      @total = net.zero? ? 0 : net + iva_sum
    end

    def iva_sum
      @iva_sum = 0.0
      self.ivas.each{ |i|
        @iva_sum += i[1] * AfipWsfe::ALIC_IVA[ i[0] ][1]
      }
      @iva_sum.round(2)
    end

    def authorize
      body = setup_bill
      response = client.call(:fecae_solicitar, message: body)

      setup_response(response.to_hash)
      self.authorized?
    end

    def setup_bill
      fecha_emision = (fch_emision || Time.zone.today).strftime('%Y%m%d')

      comp_numero = nro_comprobante || next_bill_number

      array_ivas = Array.new
      self.ivas.each{ |i|
          array_ivas << {
              "Id" => AfipWsfe::ALIC_IVA[ i[0] ][0],
              "BaseImp" => i[1] ,
              "Importe" => i[2] }
      }

      fecaereq = {
        "FeCAEReq" => {
          "FeCabReq" => AfipWsfe::Bill.header(cbte_type),
          "FeDetReq" => {
            "FECAEDetRequest" => {
              "CbteDesde"   => comp_numero,
              "CbteHasta"   => comp_numero,
              "Concepto"    => concept,
              "DocTipo"     => document,
              "DocNro"      => doc_num,
              "CbteFch"     => fecha_emision,
              "ImpTotConc"  => 0.00,
              "MonId"       => currency,
              "MonCotiz"    => exchange_rate,
              "ImpOpEx"     => 0.00,
              "ImpTrib"     => 0.00,
              "ImpNeto"     => net.to_f
            }
          }
        }
      }

      detail = fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]

      if AfipWsfe.own_iva_cond == :responsable_monotributo
        detail["ImpTotal"]  = net.to_f
      else
        detail["ImpIVA"]    = iva_sum
        detail["ImpTotal"]  = total.to_f.round(2)
        detail["Iva"]       = { "AlicIva" => array_ivas }
      end

      unless concepto == "Productos" # En "Productos" ("01"), si se mandan estos parámetros la afip rechaza.
        detail.merge!({"FchServDesde" => fch_serv_desde || today,
                      "FchServHasta"  => fch_serv_hasta || today,
                      "FchVtoPago"    => due_date       || today})
      end

      body.merge!(fecaereq)
    end

    def next_bill_number
      var = {"Auth" => AfipWsfe.auth_hash,"PtoVta" => AfipWsfe.sale_point, "CbteTipo" => cbte_type}
      resp = client.call :fe_comp_ultimo_autorizado do
        message(var)
      end

      resp.to_hash[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:cbte_nro].to_i + 1
    end

    def authorized?       
      !response.nil? && response.header_result == "A" && response.detail_result == "A"
    end

    private

    class << self
      def header(cbte_type)#todo sacado de la factura
        {"CantReg" => "1", "CbteTipo" => cbte_type, "PtoVta" => AfipWsfe.sale_point}
      end
    end

    def setup_response(response)
      result = response[:fecae_solicitar_response][:fecae_solicitar_result]
          
      if not result[:fe_det_resp] or not result[:fe_cab_resp] then 
          datos = {
            errores:       result[:errors],
            header_result: {resultado: "X"},
            observaciones:  nil
          }
          self.response = (defined?(Struct::ResponseMal) ? Struct::ResponseMal : Struct.new("ResponseMal", *datos.keys)).new(*datos.values)
          return
      end       

      response_header = result[:fe_cab_resp]
      response_detail = result[:fe_det_resp][:fecae_det_response]

      request_header  = body["FeCAEReq"]["FeCabReq"].underscore_keys.symbolize_keys
      request_detail  = body["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"].underscore_keys.symbolize_keys

      response_detail.merge!( result[:errors] ) if result[:errors]

      response_hash = {
        header_result: response_header.delete(:resultado),
        authorized_on: response_header.delete(:fch_proceso),
        detail_result: response_detail.delete(:resultado),
        cae_due_date:  response_detail.delete(:cae_fch_vto),
        cae:           response_detail.delete(:cae),
        iva_id:        request_detail.delete(:id),
        iva_importe:   request_detail.delete(:importe),
        moneda:        request_detail.delete(:mon_id),
        cotizacion:    request_detail.delete(:mon_cotiz),
        iva_base_imp:  request_detail.delete(:base_imp),
        doc_num:       request_detail.delete(:doc_nro), 
        observaciones: response_detail.delete(:observaciones),
        errores:       response_detail.delete(:err)
      }.merge!(request_header).merge!(request_detail)

      self.response = (defined?(Struct::Response) ? Struct::Response : Struct.new("Response", *response_hash.keys)).new(*response_hash.values)
    end
  end
end
