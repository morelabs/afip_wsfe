module AfipWsfe

  # This class handles authorization data
  class AuthData

    class << self

      attr_accessor :environment, :todays_data_file_name

      # Fetches WSAA Authorization Data to build the datafile for the day
      def fetch
        unless File.exists?(AfipWsfe.pkey)
          raise "Archivo de llave privada no encontrado en #{ AfipWsfe.pkey }"
        end

        unless File.exists?(AfipWsfe.cert)
          raise "Archivo certificado no encontrado en #{ AfipWsfe.cert }"
        end

        AfipWsfe::Wsaa.new.login unless File.exists?(todays_data_file_name)

        YAML.load_file(todays_data_file_name).each do |k, v|
          AfipWsfe.const_set(k.to_s.upcase, v) unless AfipWsfe.const_defined?(k.to_s.upcase)
        end
      end

      # Returns the authorization hash, containing the Token, Signature and Cuit
      def auth_hash
        fetch unless AfipWsfe.constants.include?(:TOKEN) && AfipWsfe.constants.include?(:SIGN)
        { 'Token' => AfipWsfe::TOKEN, 'Sign' => AfipWsfe::SIGN, 'Cuit' => AfipWsfe.cuit }
      end

      # Creates the data file name for a cuit number and the current day
      def todays_data_file_name
        @todays_data_file ||= "/tmp/bravo_#{ AfipWsfe.cuit }_#{ Time.zone.today.strftime('%Y_%m_%d') }.yml"
      end

      def remove
        AfipWsfe.remove_const(:TOKEN)
        AfipWsfe.remove_const(:SIGN)
        File.delete(@todays_data_file)
      end
    end
  end
end
