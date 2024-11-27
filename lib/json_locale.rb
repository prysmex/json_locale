# frozen_string_literal: true

require 'json_locale/version'

module JsonLocale
  module Translates
    def self.included(base)
      base.extend ClassMethods
      base.include InstanceMethods
    end

    class << self
      # @return [Array<Symbol>]
      attr_accessor :available_locales

      # @return [nil,Proc] called before setting the value, can be used for dirtiness
      attr_accessor :before_set

      # @return [nil,Proc,String]
      attr_accessor :default_locale

      # @return [String]
      attr_accessor :suffix

      # @return [Boolean]
      attr_accessor :allow_blank

      # @return [Boolean,:any,Array<String>]
      attr_accessor :fallback

      # @return [Boolean]
      attr_accessor :set_missing_accessor

      # @return [Boolean]
      attr_accessor :fallback_on_presence

      # Allows gem configuration
      def configure
        yield self
      end

      # default configuration
      def reset_configuration!
        @available_locales = []
        @before_set = nil
        @default_locale = nil
        @suffix = '_translations'
        @allow_blank = false
        @fallback = false
        @set_missing_accessor = false
        @fallback_on_presence = true
      end

    end

    reset_configuration!

    module ClassMethods
      NORMALIZE_LOCALE_PROC = proc do |locale|
        locale.downcase.gsub(/[^a-z]/, '')
      end

      attr_reader :translatable_attributes

      def inherited(klass)
        super
        klass.instance_variable_set(:@translatable_attributes, translatable_attributes.dup)
      end

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
      # @param [nil,Proc] before_set base attribute to be translated
      # @param [nil,Proc,String] default_locale base attribute to be translated
      # @param [Symbol] attr_name base attribute to be translated
      # @param [Symbol] suffix suffix of your translated methods
      # @param [Boolean] allow_blank
      # @param [false, :any, Array<String>] fallback
      # @param [Boolean] set_missing_accessor, if true defines accessor from attr_name param
      # @param [Boolean] fallback_on_presence
      # @return [void]
      def translates(
        attr_name,
        before_set: JsonLocale::Translates.before_set,
        default_locale: JsonLocale::Translates.default_locale,
        suffix: JsonLocale::Translates.suffix,
        allow_blank: JsonLocale::Translates.allow_blank,
        fallback: JsonLocale::Translates.fallback,
        set_missing_accessor: JsonLocale::Translates.set_missing_accessor,
        fallback_on_presence: JsonLocale::Translates.fallback_on_presence
      )
        attr_name = attr_name.to_s

        if attr_name.match(Regexp.new("#{suffix}\\z")).nil?
          raise StandardError.new("#{attr_name} does not contain the suffix #{suffix}")
        end

        if @translatable_attributes.nil?
          @translatable_attributes = []
        elsif @translatable_attributes.include?(attr_name)
          raise StandardError.new("#{attr_name} translation has already been registered")
        end

        if set_missing_accessor
          attr_reader attr_name unless instance_methods.include? attr_name
          attr_writer attr_name unless instance_methods.include? "#{attr_name}="
        end

        @translatable_attributes.push attr_name

        attr_without_suffix = attr_name.sub(suffix, '')

        # define locale agnostic getter
        define_method :"#{attr_without_suffix}" do |**params|
          # careful not to override default_locale variable
          locale = default_locale.is_a?(Proc) ? default_locale.call : default_locale
          read_json_translation(
            attr_name,
            locale: params.fetch(:locale, locale),
            fallback: params.fetch(:fallback, fallback),
            fallback_on_presence: params.fetch(:fallback_on_presence, fallback_on_presence)
          )
        end

        # define locale agnostic setter
        define_method :"set_#{attr_name}" do |value, **params|
          value.each do |locale, val|
            write_json_translation(
              attr_name,
              val,
              locale: NORMALIZE_LOCALE_PROC.call(locale.to_s),
              allow_blank: params.fetch(:allow_blank, allow_blank),
              before_set: params.fetch(:before_set, before_set)
            )
          end
        end

        # add methods for each available locale
        JsonLocale::Translates.available_locales.each do |av_locale|
          str_locale = av_locale.to_s
          normalized_locale = NORMALIZE_LOCALE_PROC.call(str_locale)

          # define getter
          define_method :"#{attr_without_suffix}_#{normalized_locale}" do |**params|
            read_json_translation(
              attr_name,
              locale: normalized_locale,
              fallback: params.fetch(:fallback, fallback),
              fallback_on_presence: params.fetch(:fallback_on_presence, fallback_on_presence)
            )
          end

          # define setter
          define_method :"set_#{attr_without_suffix}_#{normalized_locale}" do |value, **params|
            write_json_translation(
              attr_name,
              value,
              locale: normalized_locale,
              allow_blank: params.fetch(:allow_blank, allow_blank),
              before_set: params.fetch(:before_set, before_set)
            )
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
      # @param [Boolean] allow_blank if fakse and value is nil or '', the key will be deleted
      # @param [Proc] before_set
      # @return [void]
      def write_json_translation(attr_name, value, locale:, allow_blank:, before_set:)
        locale = locale&.to_s
        unless JsonLocale::Translates.available_locales.map(&:to_s).include?(locale)
          raise StandardError.new("invalid locale #{locale}")
        end

        translations = public_send(attr_name) || {}

        before_set&.call(attr_name, self) unless translations[locale] == value

        if !allow_blank && (value.nil? || value.empty?)
          translations.delete(locale)
        else
          translations[locale] = value
        end

        public_send(:"#{attr_name}=", translations)
      end

      # Get a value for a specific locale
      #
      # @param [Symbol] attr_name
      # @param [Symbol] locale
      # @param [false, :any, Array<Symbol>] fallback if Array, values must be locales
      # @param [Boolean] fallback_on_presence
      # @return [String] the value of the specified locale
      def read_json_translation(attr_name, locale:, fallback:, fallback_on_presence:)
        locale = locale&.to_s
        unless JsonLocale::Translates.available_locales.map(&:to_s).include?(locale)
          raise StandardError.new("invalid locale #{locale}")
        end

        translations = public_send(attr_name)
        return unless translations

        value = translations[locale]
        return value if matches?(translations, locale, fallback_on_presence:)

        case fallback
        when :any, true
          fallback(translations.except(locale), fallback_on_presence:)
        when String
          translations[fallback]
        when Array
          fallback(translations.slice(*fallback), fallback_on_presence:)
        end
      end

      # @return [NilClass|String]
      def fallback(translations, **)
        translations.find do |locale, _value|
          matches?(translations, locale, **)
        end&.last
      end

      # @return [Boolean]
      def matches?(translations, locale, fallback_on_presence:)
        if fallback_on_presence
          value = translations[locale]
          !value.nil? && value != ''
        else
          translations.key?(locale)
        end
      end
    end
  end
end
