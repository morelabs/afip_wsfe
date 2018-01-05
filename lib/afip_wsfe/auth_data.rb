module AfipWsfe

  class AuthData

    class << self

      attr_accessor :todays_data_file_name

      def fetch
        todays_data_file_exists = if File.exists?(todays_data_file_name)
          true
        else
          wsaa = AfipWsfe::Wsaa.new
          wsaa.login
        end

        YAML.load_file(todays_data_file_name).each do |k, v|
          AfipWsfe.const_set(k.to_s.upcase, v) unless AfipWsfe.const_defined?(k.to_s.upcase)
        end if todays_data_file_exists
      end

      def auth_hash
        fetch unless AfipWsfe.constants.include?(:TOKEN) && AfipWsfe.constants.include?(:SIGN)
        { 'Token' => AfipWsfe::TOKEN, 'Sign' => AfipWsfe::SIGN, 'Cuit' => AfipWsfe.cuit }
      end

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
