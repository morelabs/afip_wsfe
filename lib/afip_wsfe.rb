# encoding: utf-8
require 'bundler/setup'
require 'afip_wsfe/version'
require 'afip_wsfe/constants'
require 'savon'

require 'net/http'
require 'net/https'
             
module AfipWsfe

  # Exception Class for missing or invalid attributes
  class NullOrInvalidAttribute < StandardError; end

  autoload :Constants,            'afip_wsfe/constants'
  autoload :AuthData,             'afip_wsfe/auth_data'
  autoload :Wsaa,                 'afip_wsfe/wsaa'

  extend self

  attr_accessor :environment, :verbose, :log_level,
                :pkey, :cert, :openssl_bin,
                :cuit, :own_iva_cond, :sale_point,
                :default_documento, :default_concepto, :default_moneda

  def auth_hash
    {"Token" => AfipWsfe::TOKEN, "Sign" => AfipWsfe::SIGN, "Cuit" => AfipWsfe.cuit}
  end

  def log?
    AfipWsfe.verbose || ENV["BRAVO_VERBOSE"]
  end
  
  def remove_token
    AuthData.remove
  end
end
