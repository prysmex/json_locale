# frozen_string_literal: true

require 'test_helper'

class JsonLocaleTest < Minitest::Test
  def setup
    @klass = Class.new
    @klass.include JsonLocale::Translates
    Object.const_set(:Klass, @klass)
  end

  def teardown
    JsonLocale::Translates.reset_configuration!
    Object.send(:remove_const, 'Klass')
  end

  def test_configured_defaults
    assert_empty JsonLocale::Translates.available_locales
    assert_nil JsonLocale::Translates.before_set
    assert_nil JsonLocale::Translates.default_locale
    assert_equal '_translations', JsonLocale::Translates.suffix
    assert_equal false, JsonLocale::Translates.allow_blank
    assert_equal false, JsonLocale::Translates.fallback
    assert_equal false, JsonLocale::Translates.set_missing_accessor
    assert_equal true, JsonLocale::Translates.fallback_on_presence
  end

  def test_configure_methods_exist
    assert_respond_to JsonLocale::Translates, :configure

    JsonLocale::Translates.configure do |config|
      suffixes = ['', '=']
      %w[
        available_locales before_set default_locale suffix allow_blank
        fallback set_missing_accessor fallback_on_presence
      ].each do |method|
        suffixes.each do |suffix|
          assert_respond_to config, method + suffix
        end
      end
    end
  end

  def test_translates?
    assert_equal true, @klass.translates?
  end

  def test_raises_error_on_duplicate_translations
    @klass.translates :name_translations
    assert_raises(StandardError) { @klass.translates :name_translations }
  end

  def test_raises_error_with_invalid_suffix
    assert_raises(StandardError) {
      @klass.translates :name_translations, suffix: '_i18n'
    }
  end

  def test_can_add_translatable_attributes
    assert_nil @klass.translatable_attributes

    @klass.translates :name_translations

    assert_equal %w[name_translations], @klass.translatable_attributes

    @klass.translates :title_translations

    assert_equal %w[name_translations title_translations], @klass.translatable_attributes
  end

  def test_translates_defines_methods
    JsonLocale::Translates.configure do |config|
      config.available_locales = %w[es en]
      @klass.translates :name_translations, set_missing_accessor: true

      config.available_locales = %w[]
      @klass.translates :title_i18n, suffix: '_i18n', set_missing_accessor: false
    end

    record = @klass.new

    assert_respond_to record, :name_translations
    assert_respond_to record, :name_translations=
    assert_respond_to record, :name
    assert_respond_to record, :name_es
    assert_respond_to record, :name_en
    assert_respond_to record, :set_name_translations
    assert_respond_to record, :set_name_es
    assert_respond_to record, :set_name_en

    refute_respond_to record, :title_i18n
    refute_respond_to record, :title_i18n=
    assert_respond_to record, :title
    refute_respond_to record, :title_es
    refute_respond_to record, :title_en
    assert_respond_to record, :set_title_i18n
    refute_respond_to record, :set_title_es
    refute_respond_to record, :set_title_en
  end

  def test_setters
    JsonLocale::Translates.configure do |config|
      config.available_locales = %w[es en]
      config.set_missing_accessor = true
      @klass.translates :name_translations

      @klass.translates :title_i18n, suffix: '_i18n'
    end

    record = @klass.new

    #############################
    ##### name_translations #####
    #############################

    assert_nil record.name_translations

    # single language
    record.set_name_es('Nombre')

    assert_equal({ 'es' => 'Nombre' }, record.name_translations)

    record.set_name_en('Name')

    assert_equal({ 'es' => 'Nombre', 'en' => 'Name' }, record.name_translations)

    record.set_name_en('Name 2')

    assert_equal({ 'es' => 'Nombre', 'en' => 'Name 2' }, record.name_translations)

    # bulk setter
    record.set_name_translations({ es: 'Canadá', en: 'Canada' })

    assert_equal({ 'es' => 'Canadá', 'en' => 'Canada' }, record.name_translations)

    ######################
    ##### title_i18n #####
    ######################

    assert_nil record.title_i18n

    # single language
    record.set_title_es('Título')

    assert_equal({ 'es' => 'Título' }, record.title_i18n)

    record.set_title_en('Title')

    assert_equal({ 'es' => 'Título', 'en' => 'Title' }, record.title_i18n)

    record.set_title_en('Title 2')

    assert_equal({ 'es' => 'Título', 'en' => 'Title 2' }, record.title_i18n)

    # bulk setter
    record.set_title_i18n({ es: 'México', en: 'Mexico' })

    assert_equal({ 'es' => 'México', 'en' => 'Mexico' }, record.title_i18n)
  end

  def test_allow_blank
    JsonLocale::Translates.configure do |config|
      config.available_locales = %w[es en]
      config.set_missing_accessor = true
      @klass.translates :name_translations
      @klass.translates :title_i18n, suffix: '_i18n', allow_blank: true
    end

    record = @klass.new
    record.name_translations = { 'es' => 'Nombre', 'en' => 'Name' }

    # allow_blank param when true
    record.set_name_es('')
    record.set_name_en(nil)

    assert_empty(record.name_translations)

    # allow_blank override
    record.set_name_es('', allow_blank: true)
    record.set_name_en(nil, allow_blank: true)

    assert_equal({'es' => '', 'en' => nil}, record.name_translations)

    # bulk
    record.set_name_translations({ es: '', en: nil })

    assert_empty(record.name_translations)

    record.set_name_translations({ es: '', en: nil }, allow_blank: true)

    assert_equal({'es' => '', 'en' => nil}, record.name_translations)

    # allow_blank param when false
    record.set_title_es('')
    record.set_title_en(nil)

    assert_equal({'es' => '', 'en' => nil}, record.title_i18n)
  end

  def test_before_set
    JsonLocale::Translates.configure do |config|
      config.available_locales = %w[es]
      @klass.translates :name_translations, before_set: -> { raise StandardError.new('__called__') }
    end

    record = @klass.new

    assert_raises(StandardError, '__called__') { record.set_name_es('') }
    record.set_name_translations({}) # not raised
    assert_raises(StandardError, '__called__') { record.set_name_translations({'es' => 'wow'}) }
  end

  def test_getters
    JsonLocale::Translates.configure do |config|
      config.available_locales = %w[es en]
      config.set_missing_accessor = true
      @klass.translates :name_translations

      @klass.translates :title_i18n, suffix: '_i18n'
    end

    record = @klass.new

    #############################
    ##### name_translations #####
    #############################

    record.name_translations = { 'es' => 'Nombre', 'en' => 'Name' }

    assert_equal 'Nombre', record.name_es
    assert_equal 'Name', record.name_en
    assert_equal 'Nombre', record.name(locale: 'es')
    assert_equal 'Name', record.name(locale: 'en')

    ######################
    ##### title_i18n #####
    ######################

    record.title_i18n = { 'es' => 'Título', 'en' => 'Title' }

    assert_equal 'Título', record.title_es
    assert_equal 'Title', record.title_en
    assert_equal 'Título', record.title(locale: 'es')
    assert_equal 'Title', record.title(locale: 'en')
  end

  def test_default_locale
    JsonLocale::Translates.configure do |config|
      config.available_locales = %w[es en]
      config.set_missing_accessor = true

      @klass.translates :name_translations, default_locale: 'en'
      @klass.translates :title_translations, default_locale: 'en'
      @klass.translates :label_translations, default_locale: nil
      @klass.translates :text_translations, default_locale: -> { 'en' }
    end

    record = @klass.new

    record.name_translations = { 'es' => 'Nombre', 'en' => 'Name' }
    record.title_translations = { 'es' => 'Nombre', 'en' => 'Name' }
    record.label_translations = { 'es' => 'Nombre', 'en' => 'Name' }
    record.text_translations = { 'es' => 'Nombre', 'en' => 'Name' }

    assert_equal 'Name', record.name
    assert_equal 'Name', record.title
    assert_raises(StandardError) { record.label }
    assert_equal 'Name', record.text
  end

  def test_fallback
    JsonLocale::Translates.configure do |config|
      config.available_locales = %w[es en de]
      config.set_missing_accessor = true
      @klass.translates :name_translations
    end

    record = @klass.new

    # no key
    record.name_translations = { 'es' => 'Nombre', 'de' => 'Titel' }

    assert_fallbacks(record, 'es', 'Nombre', 'Nombre')
    assert_fallbacks(record, 'de', 'Titel', 'Nombre')

    # nil
    record.name_translations = { 'es' => 'Nombre', 'en' => nil, 'de' => 'Titel' }

    assert_fallbacks(record, 'es', 'Nombre', 'Nombre')
    assert_fallbacks(record, 'de', 'Titel', 'Nombre')

    # empty string
    record.name_translations = { 'es' => 'Nombre', 'en' => '', 'de' => 'Titel' }

    assert_fallbacks(record, 'es', 'Nombre', 'Nombre')
    assert_fallbacks(record, 'de', 'Titel', 'Nombre')

    # no key
    record.name_translations = { 'es' => 'Nombre', 'de' => 'Titel' }

    assert_fallbacks(record, 'es', 'Nombre', 'Nombre', fallback_on_presence: false)
    assert_fallbacks(record, 'de', 'Titel', 'Nombre', fallback_on_presence: false)

    # nil
    record.name_translations = { 'es' => 'Nombre', 'en' => nil, 'de' => 'Titel' }

    assert_fallbacks(record, 'es', nil, nil, fallback_on_presence: false)
    assert_fallbacks(record, 'de', nil, nil, fallback_on_presence: false)

    # empty string
    record.name_translations = { 'es' => 'Nombre', 'en' => '', 'de' => 'Titel' }

    assert_fallbacks(record, 'es', '', '', fallback_on_presence: false)
    assert_fallbacks(record, 'de', '', '', fallback_on_presence: false)
  end

  private

  def assert_fallbacks(record, fallback, value, any_value, **)
    assert_nil record.name_en
    assert_equal_or_nil value, record.name_en(fallback:, **)
    assert_equal_or_nil value, record.name_en(fallback: [fallback], **)
    assert_equal_or_nil any_value, record.name_en(fallback: :any, **)
    assert_equal_or_nil any_value, record.name_en(fallback: true, **)

    assert_nil record.name(locale: 'en')
    assert_equal_or_nil value, record.name(locale: 'en', fallback:, **)
    assert_equal_or_nil value, record.name(locale: 'en', fallback: [fallback], **)
    assert_equal_or_nil any_value, record.name(locale: 'en', fallback: :any, **)
    assert_equal_or_nil any_value, record.name(locale: 'en', fallback: true, **)
  end

  def assert_equal_or_nil(expected, value)
    if expected.nil?
      assert_nil(value)
    else
      assert_equal(expected, value)
    end
  end

end
