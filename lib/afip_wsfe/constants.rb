module AfipWsfe
  # This constant contains the invoice types mappings between codes and names used by WSFE.
  CBTE_TIPO = {
    '01'=>'Factura A',
    '02'=>'Nota de Débito A',
    '03'=>'Nota de Crédito A',
    '04'=>'Recibos A',
    '05'=>'Notas de Venta al contado A',
    '06'=>'Factura B',
    '07'=>'Nota de Debito B',
    '08'=>'Nota de Credito B',
    '09'=>'Recibos B',
    '10'=>'Notas de Venta al contado B',
    '11'=>'Factura C',
    '12'=>'Nota de Debito C',
    '13'=>'Nota de Credito C',
    '34'=>'Cbtes. A del Anexo I, Apartado A,inc.f),R.G.Nro. 1415',
    '35'=>'Cbtes. B del Anexo I,Apartado A,inc. f),R.G. Nro. 1415',
    '39'=>'Otros comprobantes A que cumplan con R.G.Nro. 1415',
    '40'=>'Otros comprobantes B que cumplan con R.G.Nro. 1415',
    '60'=>'Cta de Vta y Liquido prod. A',
    '61'=>'Cta de Vta y Liquido prod. B',
    '63'=>'Liquidacion A',
    '64'=>'Liquidacion B'
  }

  CBTE_LETRA = {
    '01'=>'A',
    '02'=>'A',
    '03'=>'A',
    '04'=>'A',
    '05'=>'A',
    '06'=>'B',
    '07'=>'B',
    '08'=>'B',
    '09'=>'B',
    '10'=>'B',
    '11'=>'C',
    '12'=>'C',
    '13'=>'C',
    '34'=>'A',
    '35'=>'B',
    '39'=>'A',
    '40'=>'B',
    '60'=>'A',
    '61'=>'B',
    '63'=>'A',
    '64'=>'B'
  }

  # Name to code mapping for Sale types.
  CONCEPTOS = {
    'Productos' => 1,
    'Servicios' => 2,
    'Productos y Servicios' => 3
  }

  # Name to code mapping for types of documents.
  DOCUMENTOS = {
    'CUIT'=>'80',
    'CUIL'=>'86',
    'CDI'=>'87',
    'LE'=>'89',
    'LC'=>'90',
    'CI Extranjera'=>'91',
    'en tramite'=>'92',
    'Acta Nacimiento'=>'93',
    'CI Bs. As. RNP'=>'95',
    'DNI'=>'96',
    'Pasaporte'=>'94',
    'Doc. (Otro)'=>'99'
  }

  # Currency code and names hash identified by a symbol
  MONEDAS = {
    peso:  { codigo: 'PES', nombre: 'Pesos Argentinos' },
    dolar: { codigo: 'DOL', nombre: 'Dolar Estadounidense' },
    real:  { codigo: '012', nombre: 'Real' },
    euro:  { codigo: '060', nombre: 'Euro' },
    oro:   { codigo: '049', nombre: 'Gramos de Oro Fino' }
  }

  # Tax percentage and codes according to each iva combination
  ALIC_IVA = [
    ['03', 0],
    ['04', 0.105],
    ['05', 0.21],
    ['06', 0.27]
  ]

  BILL_TYPE = {
    responsable_inscripto: {
      responsable_inscripto: '01',
      consumidor_final: '06',
      exento: '06',
      responsable_monotributo: '06',
      nota_credito_a: '03',
      nota_credito_b: '08',
      nota_debito_a: '02',
      nota_debito_b: '07'
    },
    responsable_monotributo: {
      responsable_inscripto: '11',
      consumidor_final: '11',
      exento: '11',
      responsable_monotributo: '11',
      nota_credito_c: '13',
      nota_debito_c: '12'
    }
  }
  
  # This hash keeps the set of urls for wsaa and wsfe for production and testing envs
  URLS = {
    test: {
      wsaa: 'https://wsaahomo.afip.gov.ar/ws/services/LoginCms',
      wsfe: 'https://wswhomo.afip.gov.ar/wsfev1/service.asmx'
    },
    production: {
      wsaa: 'https://wsaa.afip.gov.ar/ws/services/LoginCms',
      wsfe: 'https://servicios1.afip.gov.ar/wsfev1/service.asmx'
    }
  }
end
