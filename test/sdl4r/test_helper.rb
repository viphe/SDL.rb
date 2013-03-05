module SDL4R

  require 'date'

  module TestHelper
    
    def assert_equal_date_time(expected, actual, message = nil)
      assert_equal expected.strftime('%FT%T.%L%:z'), actual.strftime('%FT%T.%L%:z'), message
    end

    def local_civil_date(year, month, day, hour, min, sec)
      sec = Rational((sec * 1000).to_i, 1000) if sec.is_a? Float
      DateTime::civil(year, month, day, hour, min, sec, DateTime.now.offset)
    end
    
  end

end