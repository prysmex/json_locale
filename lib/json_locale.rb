require "json_locale/version"

module JsonLocale
  module Translates

    def self.included(base)
      base.extend ClassMethods
      base.include InstanceMethods
    end

    @available_locales = []
    
    class << self

      attr_reader :available_locales

      # @param [Array<Symbol>]
      def available_locales=(locales)
        raise TypeError.new('available_locales must be an Array') unless locales.is_a? Array
        @available_locales = locales
      end
      
      # @return [Proc, Symbol] if proc, should return Symbol
      attr_accessor :default_locale

      # @return [Proc] called before setting the value, can be used for dirtiness
      attr_accessor :before_set
  
      # Allows gem configuration
      def configure(&block)
        yield self
      end

    end

    module ClassMethods

      NORMALIZE_LOCALE_PROC = Proc.new do |locale|
        locale.downcase.gsub(/[^a-z]/, '')
      end

      attr_reader :translatable_attributes

      # Adds convinience methods used for managing translations on a json type attribute
      # The translated attribute must be have the suffix '_translations
      #
      # @example
      #   class SomeClass
      #     include JsonLocale::Translates
      #     translates :name_translations, {}
      #   end
      # 
      # Available instance methods:
      #
      # - instance.name
      # - instance.name_en
      # - instance.set_title_en('Some Name', {})
      # - instance.set_title_translations({en: 'Some Name'}, {})
      #
      # Available class methods:
      #
      # - SomeClass.translates?
      # - translates
      # - translatable_attributes
      #
      # @param [Symbol] attr_name base attribute to be translated
      # @param [Symbol] suffix suffix of your translated methods
      # @param [Boolean] allow_blank
      # @param [false, :any, Array<String>] fallback
      # @return [void]
      def translates(attr_name, suffix: '_translations', allow_blank: false, fallback: false)
        attr_name = attr_name.to_s

        if attr_name.match(Regexp.new("#{suffix}\\z")).nil?
          raise StandardError.new("#{attr_name} does not contain the suffix #{suffix}")
        end

        # only run on first call
        @translatable_attributes = [] if @translatable_attributes.nil?
        attr_reader attr_name unless respond_to? attr_name
        attr_writer attr_name unless respond_to? "#{attr_name}="

        if @translatable_attributes.include?(attr_name)
          raise StandardError.new("#{attr_name} translation has already been registered")
        end

        attr_without_suffix = attr_name.sub(suffix, '')

        @translatable_attributes.push attr_name

        # add methods for each available locale
        JsonLocale::Translates.available_locales.each do |locale|
          str_locale = locale.to_s
          normalized_locale = NORMALIZE_LOCALE_PROC.call(str_locale)

          # define getter
          define_method :"#{attr_without_suffix}" do |**params|
            default_locale = JsonLocale::Translates.default_locale
            default_locale = default_locale.call if default_locale.is_a?(Proc)
            read_json_translation(
              attr_name,
              locale: params.fetch(:locale, default_locale),
              fallback: params.fetch(:fallback, fallback)
            )
          end

          # define getter
          define_method :"#{attr_without_suffix}_#{normalized_locale}" do |**params|
            puts "fallback => #{fallback}"
            read_json_translation(
              attr_name,
              locale: normalized_locale,
              fallback: params.fetch(:fallback, fallback)
            )
          end

          # define setter
          define_method :"set_#{attr_without_suffix}_#{normalized_locale}" do |value, **params|
            write_json_translation(
              attr_name,
              value,
              locale: normalized_locale,
              allow_blank: params.fetch(:allow_blank, allow_blank)
            )
          end

          # define setter
          define_method :"set_#{attr_name}" do |value, **params|
            value.each do |locale, value|
              write_json_translation(
                attr_name,
                value,
                locale: NORMALIZE_LOCALE_PROC.call(locale.to_s),
                allow_blank: params.fetch(:allow_blank, allow_blank)
              )
            end
          end

        end

      end

      # @return [Boolean] true if the class supports attribute translation
      def translates?
        included_modules.include?(InstanceMethods)
      end

    end

    module InstanceMethods

      private

      # Sets a value for a specific locale
      #
      # @param [Symbol] attr_name
      # @param [String] value
      # @param [Symbol] locale
      # @param [Boolean] allow_blank if true and value is nil or '', the key will be deleted
      # @return [void]
      def write_json_translation(attr_name, value, locale:, allow_blank:)
        locale = locale&.to_s
        raise StandardError.new("invalid locale #{locale}") unless JsonLocale::Translates.available_locales.map(&:to_s).include?(locale)

        translations = public_send(attr_name) || {}

        JsonLocale::Translates.before_set&.call(attr_name, self) unless translations[locale] == value

        if !allow_blank && (value.nil? || value.empty?)
          translations.delete(locale)
        else
          translations[locale] = value
        end

        public_send("#{attr_name}=", translations)
      end

      # Get a value for a specific locale
      #
      # @param [Symbol] attr_name
      # @param [Symbol] locale
      # @param [false, :any, Array<Symbol>] fallback if Array, values must be locales
      #
      # @return [String] the value of the specified locale
      def read_json_translation(attr_name, locale:, fallback:)
        locale = locale&.to_s
        raise StandardError.new("invalid locale #{locale}") unless JsonLocale::Translates.available_locales.map(&:to_s).include?(locale)
        translations = public_send(attr_name) || {}

        if translations.key?(locale)
          translations[locale]
        else
          case fallback
          when :any
            translations.find{|k,v| !v.nil?}.try(:[], 1)
          when Array
            locale = fallback.find{|locale| !translations[locale].nil?}
            locale.nil? ? nil : translations[locale]
          end
        end
      end

    end

  end
end
