class PhoneNumberFormatter
  LOCAL_NUMBER_LENGTH = 10

  def self.format(number)
    return number if number.blank?

    has_country_code = number.to_s.strip.start_with?('+')
    digits = number.to_s.gsub(/\D/, '')
    return number if digits.length < LOCAL_NUMBER_LENGTH

    local_digits = digits[-LOCAL_NUMBER_LENGTH, LOCAL_NUMBER_LENGTH]
    formatted_local = "#{local_digits[0..2]}-#{local_digits[3..5]}-#{local_digits[6..9]}"
    return formatted_local unless has_country_code

    country_code = digits[0...-LOCAL_NUMBER_LENGTH]
    return formatted_local if country_code.blank?

    "+#{country_code}-#{formatted_local}"
  end
end
