# frozen_string_literal: true

require 'roo'
require 'pry'
require 'yaml'

module Akeneo
  class CustomMeasureUnity
    def initialize; end

    def params_families
      {
        code: 'Código (Pascal Case)',
        name_pt: 'Nome (pt_BR)',
        name_en: 'Name (en_US)'
      }
    end

    def params_measure_units
      {
        family_code_pascal: 'Código (Pascal Case)',
        unity_code: 'Código (Snake Case e Uppercase)',
        unity_name_pt: 'Nome (pt_BR)',
        unity_name_en: 'Nome (en_US)',
        unity_symbol: 'Símbolo',
        default_unity: 'Unidade Padrão?'
      }
    end

    def read_unidades_de_medida_xlsx
      filename = 'Unidades de Medida Customizadas.xlsx'
      Roo::Spreadsheet.open(filename)
    end

    def read_sheet_units
      xlsx = read_unidades_de_medida_xlsx
      xlsx.sheet('Unidades de Medida').parse(params_measure_units)
    rescue StandardError => s
      raise s, 'Failed to load sheet units'
    end

    def read_sheet_families
      xlsx = read_unidades_de_medida_xlsx
      xlsx.sheet('Famílias').parse(params_families)
    rescue StandardError => s
      raise s, 'Failed to load families'
    end

    def filter_valid_families(families)
      families - akeneo_default_families
    end

    def list_family_codes
      read_sheet_units.map { |row| row[:family_code_pascal] }.uniq.reject(&:nil?)
    end

    def families_hash(language)
      family_rows = read_sheet_families
      family_rows.map { |row| [row[:code], row[language]] }.to_h
    end

    def units_hash(language)
      units_row = read_sheet_units
      units_row = units_row.map { |row| [row[:unity_code], row[language]] }.to_h
      remove_nil_keys_or_values_from_hash(units_row)
    end

    def remove_nil_keys_or_values_from_hash(any_map)
      any_map.reject{ |key| key.nil? }.reject { |_key, value| value.nil? }
    end

    def pim_measure_hash(language)
      units = units_hash("unity_name_#{language}".to_sym)
      families = families_hash("name_#{language}".to_sym)
      families = remove_nil_keys_or_values_from_hash(families)
      {
        'pim_measure' => {
          'families' => families,
          'units' => units
        }
      }
    end

    def measure_family_hash(family_name)
      units_from_family = read_sheet_units.map.select { |row| row[:family_code_pascal] == family_name }
      std_unity_code = standard_unity_code(units_from_family)
      units = units_details(units_from_family)
      units_hash = { 'units' => units }
      std_hash = { 'standard' => std_unity_code }
      std_hash.merge(units_hash) unless std_unity_code.nil?
    end

    def measure_config
      {
        "measures_config" =>
          list_family_codes.map { |family_code| [family_code, measure_family_hash(family_code)] }.to_h
      }
    end

    def standard_unity_code(unity_rows)
      selected_rows = unity_rows.select { |row| row[:default_unity] == "Sim" }
      selected_rows.empty? ? nil : selected_rows.first[:unity_code]
    end

    def options
      "[{'mul': '1'}]"
    end

    def units_details(unity_rows)
      unity_rows.map { |row| [row[:unity_code].to_s, {"convert" => options, "symbol" => row[:unity_symbol] }] }.to_h
    end
  end
end

configs_generator = Akeneo::CustomMeasureUnity.new

message_en = configs_generator.pim_measure_hash("en").to_yaml.gsub(/\"/, "")
message_pt = configs_generator.pim_measure_hash("pt").to_yaml.gsub(/\"/, "")
mconf = configs_generator.measure_config.to_yaml.gsub(/\"/, "")


File.open("measure.yml", "w") { |file| file.write(mconf) }
File.open("messages.pt_BR.yml", "w") { |file| file.write(message_pt) }
File.open("messages.en_US.yml", "w") { |file| file.write(message_en) }
