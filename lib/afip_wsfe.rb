# encoding: utf-8
require 'bundler/setup'
require 'savon'
require 'afip_wsfe/version'
require 'afip_wsfe/constants'
require 'afip_wsfe/client'

require 'net/http'
require 'net/https'
             
module AfipWsfe

  # Exception Class for missing or invalid attributes
  class NullOrInvalidAttribute < StandardError; end

  autoload :Constants, 'afip_wsfe/constants'
  autoload :AuthData,  'afip_wsfe/auth_data'
  autoload :Client,    'afip_wsfe/client'
  autoload :Wsaa,      'afip_wsfe/wsaa'
  autoload :Bill,      'afip_wsfe/bill'

  extend self

  attr_accessor :environment, :verbose, :log_level,
                :pkey, :cert, :storage
                :cuit, :own_iva_cond, :sale_point,
                :default_documento, :default_concepto, :default_moneda

  def auth_hash
    AuthData.auth_hash
  end

  def log?
    AfipWsfe.verbose || ENV["WSFE_VERBOSE"]
  end
  
  def remove_token
    AuthData.remove
  end

  def enabled?
    if self.storage == :file 
      File.exists?(AfipWsfe.pkey || "") && File.exists?(AfipWsfe.cert || "")
    else
      AfipWsfe.pkey.present? && AfipWsfe.cert.present?
    end
  end
end
