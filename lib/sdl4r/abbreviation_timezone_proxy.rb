# To change this template, choose Tools | Templates
# and open the template in the editor.

module SDL4R
  class AbbreviationTimezoneProxy < TZInfo::Timezone

    def self.new(identifier, consider_modern_abbreviations)
      o = super()
      o._initialize(identifier, consider_modern_abbreviations)
      o
    end

    def _initialize(identifier, consider_modern_abbreviations)
      @identifier = identifier
      @consider_modern_abbreviations = consider_modern_abbreviations
      @actual_timezone = nil
    end

    def actual_timezone
      unless @actual_timezone
        @actual_timezone = get_timezone(identifier, consider_modern_abbreviations)
      end
      @actual_timezone
    end

    def identifier
      @identifier
    end

    def period_for_utc(utc)
      actual_timezone.period_for_utc(utc)
    end

    def periods_for_local(local)
      actual_timezone.periods_for_local(local)
    end
  end
end
