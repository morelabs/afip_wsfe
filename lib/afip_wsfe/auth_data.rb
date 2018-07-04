module AfipWsfe

  class AuthData

    class << self

      attr_accessor :todays_data_file_name

      def auth_hash
        fetch unless AfipWsfe.constants.include?(:TOKEN) && AfipWsfe.constants.include?(:SIGN)
        
        {
          auth: {
            token: AfipWsfe::TOKEN,
            sign: AfipWsfe::SIGN,
            cuit: AfipWsfe.cuit,
          }
        }
      end

      def todays_data_file_name
        @todays_data_file ||= "/tmp/afip_wsfe_#{ AfipWsfe.cuit }_#{ Time.zone.today.strftime('%Y_%m_%d') }.yml"
      end

      private
      
      def fetch
        unless File.exists?(todays_data_file_name)
          wsaa = AfipWsfe::Wsaa.new
          wsaa.login
        end

        YAML.load_file(todays_data_file_name).each do |k, v|
          AfipWsfe.const_set(k.to_s.upcase, v)
        end
      end

      def remove
        AfipWsfe.remove_const(:TOKEN)
        AfipWsfe.remove_const(:SIGN)
        File.delete(@todays_data_file)
      end
    end
  end
end
