module AfipWsfe
  class Bill
    attr_reader :base_imp, :total
    attr_accessor :fch_emision, :fch_vto_pago, :fch_serv_desde, :fch_serv_hasta,
                  :tipo_comprobante, :nro_comprobante, :doc_num, :net, 
                  :iva_cond, :documento, :concepto, :moneda, :ivas, 
                  :body, :response

    def initialize(attrs = {})
      @client   = AfipWsfe::Client.new
      @endpoint = :wsfe
      @response = nil
      @status   = false

      self.net        = attrs[:net] || 0
      self.iva_cond   = attrs[:iva_cond]  || :responsable_monotributo
      self.documento  = attrs[:documento] || AfipWsfe.default_documento
      self.concepto   = attrs[:concepto]  || AfipWsfe.default_concepto
      self.moneda     = attrs[:moneda]    || AfipWsfe.default_moneda
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
      @status, @response = @client.call_endpoint @endpoint, :fe_param_get_cotizacion, {"MonId" => AfipWsfe::MONEDAS[moneda][:codigo]}
      @response[:result_get][:mon_cotiz].to_f
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
      setup_bill
      @status, @response = @client.call_endpoint(@endpoint, :fecae_solicitar, self.body)
      setup_response
      self.authorized?
    end

    def last_bill_number
      raise(NullOrInvalidAttribute.new, "No está definido el punto de venta.") unless AfipWsfe.sale_point
      raise(NullOrInvalidAttribute.new, "No está definido el tipo de comprobante.") unless tipo_comprobante
      
      params = {
        "PtoVta" => AfipWsfe.sale_point,
        "CbteTipo" => tipo_comprobante
      }
      
      @status, @response = @client.call_endpoint @endpoint, :fe_comp_ultimo_autorizado, params
      @response[:cbte_nro].to_i
    end

    def next_bill_number
      last_bill_number + 1
    end

    def authorized?       
      @response && @response[:header_result] == "A"
    end

    private

    def setup_bill
      today = Time.zone.today.strftime('%Y%m%d')

      fecha_emision = (fch_emision || today)

      self.tipo_comprobante ||= cbte_type
      self.nro_comprobante ||= next_bill_number

      array_ivas = Array.new
      self.ivas.each{ |i|
          array_ivas << {
              "Id" => AfipWsfe::ALIC_IVA[ i[0] ][0],
              "BaseImp" => i[1] ,
              "Importe" => i[2] }
      }

      fecaereq = {
        "FeCAEReq" => {
          "FeCabReq" => {
            "CantReg" => "1",
            "CbteTipo" => tipo_comprobante,
            "PtoVta" => AfipWsfe.sale_point
          },
          "FeDetReq" => {
            "FECAEDetRequest" => {
              "CbteDesde"   => nro_comprobante,
              "CbteHasta"   => nro_comprobante,
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
        detail["ImpTotal"]  = net.to_f.round(2)
      else
        detail["ImpIVA"]    = iva_sum
        detail["ImpTotal"]  = total.to_f.round(2)
        detail["Iva"]       = { "AlicIva" => array_ivas }
      end

      unless concepto == "Productos" # En "Productos" ("01"), si se mandan estos parámetros la afip rechaza.
        detail.merge!({"FchServDesde" => fch_serv_desde || today,
                      "FchServHasta"  => fch_serv_hasta || today,
                      "FchVtoPago"    => fch_vto_pago   || today})
      end

      self.body = fecaereq
    end

    def setup_response
      if not @response[:fe_det_resp] or not @response[:fe_cab_resp]
          @response = {
            errores:       @response[:errors],
            header_result: {resultado: "X"},
            detail_result: {resultado: "X"},
            observaciones:  nil
          }
          return
      end       

      response_header = @response[:fe_cab_resp]
      response_detail = @response[:fe_det_resp][:fecae_det_response]

      request_header  = body["FeCAEReq"]["FeCabReq"].transform_keys { |key| key.to_s.downcase.to_sym }
      request_detail  = body["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"].transform_keys { |key| key.to_s.downcase.to_sym }

      response_detail.merge!( @response[:errors] ) if @response[:errors]

      self.response = {
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
    end
  end
end
