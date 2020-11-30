# JsonLocale

JsonLocale provides a simple api for managing translated data inside a json field by providing convinient methods to manage the translation values, along with fallbacks and some conventions for drying your code.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'json_locale'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install json_locale

## Usage

Let's build an example where you have an attribute `Country.name_translations` that you want translate in multiple locales.

Notice the suffix `_translations`, you can customize it but a suffix is required to differentiate the main method from generated methods.

```ruby
JsonLocale::Translates.available_locales=['en', 'es', 'de']

class Country
    include JsonLocale::Translates
    # if you want to change the suffix, add suffix: '_your_suffix'
    translates :name_translations, {allow_blank: false, fallback: false}
end

record = Country.new(name_translations: {'en' => 'Germany', 'es' => 'Alemania'}

# return raw value
name_translations => {'en' => 'Germany', 'es' => 'Alemania'}
```


## Getters
```ruby
I18n.locale = :en

# title methods
record.title => 'Germany'
record.title(locale: 'es') => 'Alemania'
record.title(locale: 'de', fallback: ['es']) => 'Alemania'

#return value in specific locale
record.title_en => 'Germany'
record.title_de(fallback:['es']) => 'Germany'
```

## Setters
```ruby
#set value for a specific locale

record.set_name_es('') #removes the value due to allow_blank: false
record.name_translations => {'en' => 'Germany'}

record.set_name_es('', {allow_empty: true}) #override allow_empty option
record.name_translations => {'en' => 'Germany', 'es' => ''}

#used to set multiple translations at a time (merges)
record.set_title_translations({es: 'Canadá', en: 'Canada'})
```

## Fallbacks
```ruby
fallback: false => # no fallback
fallback: :any => # fall back first to the default locale, then to any other locale
fallback: [:sv] => # explicitly declare fallbacks as an array of any length
```
