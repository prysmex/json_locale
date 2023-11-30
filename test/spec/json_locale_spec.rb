require "test_helper"

class ClassTest < Minitest::Test

  def setup
    JsonLocale::Translates.set_missing_accessor = true

    @klass = Class.new
    @klass.include JsonLocale::Translates
    Object.const_set('Klass', @klass)
  end

  def teardown
    Object.send(:remove_const, 'Klass')

    # remove all configurations
    JsonLocale::Translates.configure do |config|
      config.default_locale = nil
      config.available_locales = []
      config.before_set = nil
    end
  end

  def test_configure
    assert_respond_to JsonLocale::Translates, :configure

    assert_nil JsonLocale::Translates.default_locale
    assert_empty JsonLocale::Translates.available_locales
    assert_nil JsonLocale::Translates.before_set

    JsonLocale::Translates.configure do |config|
      config.default_locale = 'en'
      config.available_locales = ['en']
      config.before_set = Proc.new{}
    end

    assert_equal 'en', JsonLocale::Translates.default_locale
    assert_equal 'en', JsonLocale::Translates.available_locales.first
    assert_instance_of Proc, JsonLocale::Translates.before_set
  end

  def test_translates?
    assert_equal true, @klass.translates?
  end

  def test_can_add_translatable_attributes
    assert_nil @klass.translatable_attributes
    
    @klass.translates :name_translations
    assert_equal 1, @klass.translatable_attributes.size
    assert_equal 'name_translations', @klass.translatable_attributes.first

    @klass.translates :title_translations
    assert_equal 2, @klass.translatable_attributes.size
  end

  def test_raises_error_on_duplicate_translations
    @klass.translates :name_translations
    assert_raises(StandardError){ @klass.translates :name_translations }
  end

  def test_raises_error_with_invalid_suffix
    assert_raises(StandardError){
      @klass.translates :name_translations, suffix: '_i18n'
    }
  end

  def test_setters
    JsonLocale::Translates.configure do |config|
      config.available_locales = ['es', 'en']
    end

    @klass.translates :name_translations
    @klass.translates :title_i18n, suffix: '_i18n', allow_blank: true
    record = @klass.new
    
    # single language
    record.set_name_es('Prueba')
    assert_equal 'Prueba', record.name_translations['es']
    record.set_name_en('Test')
    assert_equal 'Test', record.name_translations['en']

    # bulk setter
    record.set_name_translations({es: 'Canadá', en: 'Canada'})
    assert_equal 'Canadá', record.name_translations['es']
    assert_equal 'Canada', record.name_translations['en']

    # allow_blank param when true
    record.set_name_es('')
    record.set_name_en(nil)
    assert_equal false, record.name_translations.key?('es')
    assert_equal false, record.name_translations.key?('en')

    # allow_blank override
    record.set_name_es('', allow_blank: true)
    assert_equal '', record.name_translations['es']

    # allow_blank param when false
    record.set_title_es('')
    record.set_title_en(nil)
    assert_equal '', record.title_i18n['es']
    assert_nil record.title_i18n['en']
  end

  def test_getters
    JsonLocale::Translates.configure do |config|
      config.available_locales = ['es', 'en', 'de']
    end

    @klass.translates :name_translations, fallback: false
    @klass.translates :title_i18n, suffix: '_i18n', fallback: ['es']
    record = @klass.new

    # getters
    record.set_name_es('Prueba')
    assert_equal 'Prueba', record.name_es
    assert_equal 'Prueba', record.name(locale: 'es')

    record.set_name_en('Test')
    assert_equal 'Test', record.name_en

    # default fallback
    record.set_title_es('Prueba')
    assert_equal 'Prueba', record.title_en

    # override fallback
    assert_equal 'Test', record.name_de(fallback: ['en'])
  end

end